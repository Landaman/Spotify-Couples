import {
	getFirestore,
	Timestamp,
	type FirestoreDataConverter,
	type QueryDocumentSnapshot
} from 'firebase-admin/firestore';
import type { User } from 'lucia';
import { FirestoreUserConverter, USER_COLLECTION_NAME } from '../lucia';

// The name of the firestore collection being used for pairing
export const FirestorePairingCodeCollectionName = 'pairing_codes';

// Some math around pairing codes
const ValidPairingCodeCharacters = characterRange('A', 'Z').concat(characterRange('0', '9')); // Characters we consider acceptable for pairing codes
const PairingCodeLength = 6;
const PairingCodeTimeToLiveMilliseconds = 15 * 60 * 1000; // TTL for a pairing code in minutes. 15 minutes

export interface PairingCode {
	/**
	 * The pairing code itself
	 */
	code: string;
	/**
	 * The date/time the pairing code expires at
	 */
	expiry: Date;
}

/**
 * Type representing a code in Firestore, including the user it represents and the codes expiry
 */
interface FirestorePairingCode {
	/**
	 * The expiry of the code
	 */
	expiry: Timestamp;
}

/**
 * Converter from a Firestore code to a PairingCode and vice versa
 */
export const FirestorePairingCodeConverter: FirestoreDataConverter<
	PairingCode,
	FirestorePairingCode
> = {
	toFirestore(pairingCode: PairingCode): FirestorePairingCode {
		return {
			expiry: Timestamp.fromDate(pairingCode.expiry)
		};
	},

	fromFirestore(
		firestorePairingCode: QueryDocumentSnapshot<FirestorePairingCode, FirestorePairingCode>
	): PairingCode {
		const data = firestorePairingCode.data();
		return {
			expiry: data.expiry.toDate(),
			code: firestorePairingCode.id
		};
	}
};

/**
 * Generates a range (array of numbers) starting at the provided value and being of size size
 * @param size the size of the array
 * @param startAt the value to start the array at
 * @returns the values in the range [startAt, startAt + size]
 */
function range(size: number, startAt = 0): readonly number[] {
	return [...Array(size).keys()].map((i) => i + startAt);
}

/**
 * Generates a range (array of characters) from the provided start to the provided end character
 * @param startChar the starting character
 * @param endChar the ending character
 * @returns the characters between and including the provided characters
 */
function characterRange(startChar: string, endChar: string): readonly string[] {
	return String.fromCharCode(
		...range(endChar.charCodeAt(0) - startChar.charCodeAt(0), startChar.charCodeAt(0))
	).split('');
}

/**
 * Generates a random pairing code. Makes no guarantees of uniqueness. Valid characters are A-Z, 0-9
 * @returns a random pairing code that may or may not be unique
 */
function generateRandomPairingCode(): string {
	let code = '';

	for (let i = 0; i < PairingCodeLength; i++) {
		code +=
			ValidPairingCodeCharacters[Math.floor(Math.random() * ValidPairingCodeCharacters.length)];
	}

	return code;
}

/**
 * Exception for when a user already has a partner and thus should not be allowed to
 * generate/get a pairing code
 */
export class HasPartnerException extends Error {}

export class InvalidPairingCodeException extends Error {}

/**
 * Gets or generates a pairing code for the provided user
 * @param user the user to get or generate the pairing code for
 * @returns the users pairing code, if they have a valid one, or a new one if they do not
 * @throws {HasPartnerException} if the user has a partner already (they cannot have a pairing code in this case)
 */
export async function getOrGeneratePairingCode(user: User): Promise<PairingCode> {
	const firestore = getFirestore();

	// Loop until we get a unique pairing code
	let result: PairingCode;
	while (true) {
		const pairingCodeString = generateRandomPairingCode(); // We cannot do this in the tx, since create on an already-existing doc will fail the tx in Firestore
		try {
			result = await firestore.runTransaction(async (t) => {
				const userDocument = firestore
					.collection(USER_COLLECTION_NAME)
					.withConverter(FirestoreUserConverter)
					.doc(user.id);
				const transactionUser = (await t.get(userDocument)).data(); // This also ensures that the user can't try to generate two pairing codes at once

				// Ensure the user does not have a partner already
				if (transactionUser?.attributes.partnerId) {
					throw new HasPartnerException(); // Throw if they do
				}

				// If the user already has a pairing code, check if it is valid
				if (transactionUser?.attributes.pairingCode) {
					const alreadyExistingPairingCode = (
						await t.get(
							firestore
								.collection(FirestorePairingCodeCollectionName)
								.withConverter(FirestorePairingCodeConverter)
								.doc(transactionUser.attributes.pairingCode)
						)
					).data();

					// If the pairing code is still valid, we can return it. If it is null (doesn't exit, potentially Firestore TTL)
					// or just invalid, we should proceed with creating a new one
					if (alreadyExistingPairingCode && alreadyExistingPairingCode.expiry > new Date()) {
						return alreadyExistingPairingCode;
					}
				}

				const pairingCodeDocument = firestore
					.collection(FirestorePairingCodeCollectionName)
					.withConverter(FirestorePairingCodeConverter)
					.doc(pairingCodeString);

				const pairingCodeData = {
					expiry: new Date(new Date().getTime() + PairingCodeTimeToLiveMilliseconds),
					code: pairingCodeString
				};

				// Create the document with the new pairing code.
				t.create(pairingCodeDocument, pairingCodeData);

				// Update the user to actually have the pairing code. This syntax is gross but will correctly update the attribute
				t.update(userDocument, { 'attributes.pairingCode': pairingCodeString });

				return pairingCodeData;
			});

			break; // If we got this far without throwing, we have a valid code and can break
		} catch (error) {
			// If we got an ALREADY_EXISTS error (6) we can just retry
			if (error instanceof Error && error.message.startsWith('6 ALREADY_EXISTS')) {
				continue;
			}

			throw error;
		}
	}

	return result;
}

export async function pair(pairingCode: string, user: User): Promise<User> {
	const firestore = getFirestore();

	return await firestore.runTransaction(async (t) => {
		const userDocument = firestore
			.collection(USER_COLLECTION_NAME)
			.withConverter(FirestoreUserConverter)
			.doc(user.id);
		const transactionUser = (await t.get(userDocument)).data(); // This also ensures that the user can't try to pair and generate a code at the same time
		if (!transactionUser) {
			throw new Error('Failed to fetch user');
		}

		// Ensure the user does not have a partner already
		if (transactionUser?.attributes.partnerId) {
			throw new HasPartnerException(); // Throw if they do
		}

		// If this pairing code belongs to this user, it's automatically invalid
		if (transactionUser?.attributes.pairingCode === pairingCode) {
			throw new InvalidPairingCodeException();
		}

		// Now check the validity of the pairing code
		const pairingCodeDocument = firestore
			.collection(FirestorePairingCodeCollectionName)
			.withConverter(FirestorePairingCodeConverter)
			.doc(pairingCode);
		const transactionPairingCode = (await t.get(pairingCodeDocument)).data();

		// If the pairing code isn't valid, or is expired, we can't pair with it
		if (!transactionPairingCode || transactionPairingCode.expiry <= new Date()) {
			throw new InvalidPairingCodeException();
		}

		// Get the user to pair with, including their document
		const usersToPairWithDocument = firestore
			.collection(USER_COLLECTION_NAME)
			.withConverter(FirestoreUserConverter)
			.where('attributes.pairingCode', '==', pairingCode);
		const transactionUsersToPairWith = await t.get(usersToPairWithDocument);
		if (transactionUsersToPairWith.docs.length !== 1) {
			// Sanity check, this should never happen
			throw new Error(
				`Found ${transactionUsersToPairWith.docs.length} users with pairing code ${pairingCode}, expected 1`
			);
		}
		const userToPairWithDocument = transactionUsersToPairWith.docs[0].ref;
		const transactionUserToPairWith = (await t.get(userToPairWithDocument)).data();
		if (transactionUserToPairWith?.attributes.partnerId !== null) {
			// Sanity check, this should never happen
			throw new Error(
				`Tried to pair with ${transactionUserToPairWith?.id} (who already has a partner) using pairing code ${pairingCode}`
			);
		}

		t.update(userDocument, {
			'attributes.partnerId': transactionUserToPairWith.id,
			'attributes.pairingCode': null
		});
		t.update(userToPairWithDocument, {
			'attributes.partnerId': transactionUser.id,
			'attributes.pairingCode': null
		});
		t.delete(pairingCodeDocument);

		// Delete the other users pairing code if necessary
		if (transactionUserToPairWith.attributes.pairingCode) {
			t.delete(
				firestore
					.collection(FirestorePairingCodeCollectionName)
					.withConverter(FirestorePairingCodeConverter)
					.doc(transactionUserToPairWith.attributes.pairingCode)
			);
		}

		return {
			id: transactionUserToPairWith.id,
			...transactionUserToPairWith.attributes,
			partnerId: transactionUser.id
		};
	});
}
