import { client, getOrCreateUser } from './helpers';

/**
 * Generate a local magic link for an email address, creating the user if needed
 * @param email the email address to sign in with
 * @returns resolves after printing the one-time login URL
 */
export default async function generateLoginLink(email: string): Promise<void> {
	await getOrCreateUser(email, email, email.split('@')[0]);

	const { data, error } = await client.auth.admin.generateLink({ type: 'magiclink', email });
	if (error) throw error;

	const loginUrl = new URL('http://localhost:5173/signin');
	loginUrl.searchParams.set('token_hash', data.properties.hashed_token);
	console.log(loginUrl.toString());
}
