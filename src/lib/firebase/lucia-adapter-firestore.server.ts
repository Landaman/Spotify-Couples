import {
	Timestamp,
	type Firestore,
	type FirestoreDataConverter,
	type QueryDocumentSnapshot,
	type QuerySnapshot
} from 'firebase-admin/firestore';
import type {
	Adapter,
	DatabaseSession as LuciaSession,
	DatabaseUser as LuciaUser,
	RegisteredDatabaseSessionAttributes,
	RegisteredDatabaseUserAttributes,
	UserId
} from 'lucia';

/**
 * Config for the Firestore adapter
 */
interface FirestoreAdapterConfig {
	/**
	 * Name for the collection users will be stored in
	 */
	userCollectionName: string;
	/**
	 * Name for the sub-collection sessions will be stored in. Note: a sub-collection index is required over this
	 */
	sessionSubCollectionName: string;
	/**
	 * The Firestore instance to run queries on
	 */
	firestore: Firestore;
}

/**
 * Type representing a session in Firestore
 */
interface FirestoreSession {
	id: string; // This may seem strange but we actually need this to query across the collection group
	expiresAt: Timestamp;
	attributes: RegisteredDatabaseSessionAttributes;
}

/**
 * Converter that handles converting a Firestore session to a Lucia session and vice versa
 */
export const FirestoreSessionConverter: FirestoreDataConverter<LuciaSession, FirestoreSession> = {
	toFirestore(luciaSession: LuciaSession): FirestoreSession {
		return {
			id: luciaSession.id,
			expiresAt: Timestamp.fromDate(luciaSession.expiresAt),
			attributes: luciaSession.attributes
		};
	},

	fromFirestore(
		firestoreSession: QueryDocumentSnapshot<FirestoreSession, FirestoreSession> // Use both because this hasn't applied yet
	): LuciaSession {
		const firestoreSessionData = firestoreSession.data();
		return {
			id: firestoreSession.id,
			userId: firestoreSession.ref.parent.id,
			attributes: firestoreSessionData.attributes,
			expiresAt: firestoreSessionData.expiresAt.toDate()
		};
	}
};

/**
 * Type representing a user in Firestore
 */
interface FirestoreUser {
	attributes: RegisteredDatabaseUserAttributes;
}

/**
 * Converter that handles converting a Firestore user to a Lucia user and vice versa
 */
export const FirestoreUserConverter: FirestoreDataConverter<LuciaUser, FirestoreUser> = {
	toFirestore(luciaUser: LuciaUser): FirestoreUser {
		return {
			attributes: luciaUser.attributes
		};
	},

	fromFirestore(firestoreUser: QueryDocumentSnapshot<FirestoreUser, FirestoreUser>): LuciaUser {
		const firestoreUserData = firestoreUser.data();
		return {
			attributes: firestoreUserData.attributes,
			id: firestoreUser.id
		};
	}
};

/**
 * Adapter for Lucia built on top of Firestore
 */
export class FirestoreAdapter implements Adapter {
	private readonly userCollectionName: string;
	private readonly sessionSubCollectionName: string;
	private readonly firestore: Firestore;
	/**
	 * Creates the adapter. Note that this does not actually involve any
	 * connection to firebase
	 * @param config
	 */
	constructor(config: FirestoreAdapterConfig) {
		this.userCollectionName = config.userCollectionName;
		this.sessionSubCollectionName = config.sessionSubCollectionName;
		this.firestore = config.firestore;
	}

	/**
	 * This is unnecessary using Firestore, TTL will
	 * handle cleanup automatically
	 */
	async deleteExpiredSessions(): Promise<void> {
		return;
	}

	async deleteSession(sessionId: string): Promise<void> {
		// Get the session documents associated with the provided ID
		const sessionDocuments = (await this.getAndValidateSessionDocuments(sessionId)).docs;

		// Edge case, no session
		if (sessionDocuments.length == 0) {
			return; // No need to do anything, session is already deleted
		}

		sessionDocuments[0].ref.delete(); // Otherwise, delete the session
	}

	/**
	 * Gets the session document associated with the provided session ID
	 * @param sessionId the session to get the document for
	 * @returns the session document associated with the provided ID. This returns
	 * the query, so users can determine how to handle no session found. This means
	 * docs is an array, even though there is <= 1 doc with a given ID
	 */
	private async getSessionDocuments(
		sessionId: string
	): Promise<QuerySnapshot<LuciaSession, FirestoreSession>> {
		return await this.firestore
			.collectionGroup(this.sessionSubCollectionName)
			.withConverter(FirestoreSessionConverter)
			.where('id', '==', sessionId) // We can't query across the actual ID because we're looking at a collection group
			.get();
	}

	/**
	 * Gets the user session documents (Firestore) associated with the provided user
	 * @param userId the user ID to get the session for
	 * @returns the session documents associated with the provided user
	 */
	private async getUserSessionDocuments(
		userId: UserId
	): Promise<QuerySnapshot<LuciaSession, FirestoreSession>> {
		return await this.firestore
			.collection(this.userCollectionName)
			.doc(userId)
			.collection(this.sessionSubCollectionName)
			.withConverter(FirestoreSessionConverter)
			.get();
	}

	async getUserSessions(userId: UserId): Promise<LuciaSession[]> {
		return Array.from((await this.getUserSessionDocuments(userId)).docs).map(
			(userSessionDocument) => userSessionDocument.data()
		);
	}

	async deleteUserSessions(userId: UserId): Promise<void> {
		(await this.getUserSessionDocuments(userId)).docs.forEach((userSessionDocument) =>
			userSessionDocument.ref.delete()
		);
	}

	async getSessionAndUser(
		sessionId: string
	): Promise<[session: LuciaSession | null, user: LuciaUser | null]> {
		// Get the session doc, validate it exists
		const sessionDocuments = await this.getAndValidateSessionDocuments(sessionId);
		if (sessionDocuments.docs.length == 0) {
			return [null, null]; // This will happen if the session token is invalid
		}

		const sessionDocument = sessionDocuments.docs[0];

		// The parent doc of the session is the session collection, whose parent is the user
		const userDocument = await sessionDocument.ref.parent.parent
			?.withConverter(FirestoreUserConverter)
			.get();
		const userDocumentData = userDocument?.data();
		if (!userDocument || !userDocumentData) {
			return [null, null]; // This shouldn't happen but is technically possible
		}
		// Now return the data for both
		return [sessionDocument.data(), userDocumentData];
	}

	async setSession(session: LuciaSession): Promise<void> {
		// Get the user, then get their sessions, then create the session
		await this.firestore
			.collection(this.userCollectionName)
			.withConverter(FirestoreUserConverter)
			.doc(session.userId)
			.collection(this.sessionSubCollectionName) // This creates if it doesn't exist
			.withConverter(FirestoreSessionConverter)
			.doc(session.id)
			.set(session); // This sets or creates the session
	}

	/**
	 * Gets and validates the session documents for the given session ID (ensures there is at most 1)
	 * @param sessionId the session ID to get and validate documents for
	 * @returns the session documents associated with the given sesssion ID (must be 0 or 1)
	 * @throws {Error} if there is more than one session in the provided lookup
	 */
	async getAndValidateSessionDocuments(
		sessionId: string
	): Promise<QuerySnapshot<LuciaSession, FirestoreSession>> {
		const sessionDocuments = await this.getSessionDocuments(sessionId);

		if (sessionDocuments.docs.length > 1) {
			throw new Error(
				`Found ${sessionDocuments.docs.length} sessions for session ID ${sessionId}. Expected at most 1`
			);
		}

		return sessionDocuments;
	}

	async updateSessionExpiration(sessionId: string, expiresAt: Date): Promise<void> {
		// Get the session
		const sessionDocuments = await this.getAndValidateSessionDocuments(sessionId);

		// Update its expiry. Pass up the error if we have no valid session
		sessionDocuments.docs[0].ref.update({
			expiresAt
		});
	}
}
