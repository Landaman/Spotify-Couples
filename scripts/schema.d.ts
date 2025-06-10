export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface Database {
	graphql_public: {
		Tables: Record<never, never>;
		Views: Record<never, never>;
		Functions: {
			graphql: {
				Args: {
					operationName?: string;
					query?: string;
					variables?: Json;
					extensions?: Json;
				};
				Returns: Json;
			};
		};
		Enums: Record<never, never>;
		CompositeTypes: Record<never, never>;
	};
	public: {
		Tables: {
			pairing_codes: {
				Row: {
					code: string;
					expires_at: string;
					owner_id: string;
				};
				Insert: {
					code: string;
					expires_at: string;
					owner_id: string;
				};
				Update: {
					code?: string;
					expires_at?: string;
					owner_id?: string;
				};
				Relationships: [];
			};
			pairings: {
				Row: {
					one_uuid: string;
					two_uuid: string;
				};
				Insert: {
					one_uuid: string;
					two_uuid: string;
				};
				Update: {
					one_uuid?: string;
					two_uuid?: string;
				};
				Relationships: [];
			};
			plays: {
				Row: {
					id: string;
					played_date_time: string;
					spotify_id: string;
					spotify_played_context_uri: string | null;
					user_id: string;
				};
				Insert: {
					id?: string;
					played_date_time: string;
					spotify_id: string;
					spotify_played_context_uri?: string | null;
					user_id: string;
				};
				Update: {
					id?: string;
					played_date_time?: string;
					spotify_id?: string;
					spotify_played_context_uri?: string | null;
					user_id?: string;
				};
				Relationships: [];
			};
			profiles: {
				Row: {
					id: string;
					name: string;
					picture_url: string | null;
					spotify_id: string;
				};
				Insert: {
					id: string;
					name: string;
					picture_url?: string | null;
					spotify_id: string;
				};
				Update: {
					id?: string;
					name?: string;
					picture_url?: string | null;
					spotify_id?: string;
				};
				Relationships: [];
			};
		};
		Views: Record<never, never>;
		Functions: {
			get_or_create_pairing_code: {
				Args: Record<PropertyKey, never>;
				Returns: {
					code: string;
					expires_at: string;
					owner_id: string;
				};
			};
			get_partner_id: {
				Args: Record<PropertyKey, never> | { search_uuid: string };
				Returns: string;
			};
			pair_with_code: {
				Args: { pairing_code: string };
				Returns: undefined;
			};
			process_spotify_refresh_token: {
				Args: { refresh_token: string };
				Returns: undefined;
			};
		};
		Enums: Record<never, never>;
		CompositeTypes: Record<never, never>;
	};
}

type DefaultSchema = Database[Extract<keyof Database, 'public'>];

export type Tables<
	DefaultSchemaTableNameOrOptions extends
		| keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
		| { schema: keyof Database },
	TableName extends DefaultSchemaTableNameOrOptions extends {
		schema: keyof Database;
	}
		? keyof (Database[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
				Database[DefaultSchemaTableNameOrOptions['schema']]['Views'])
		: never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
	? (Database[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
			Database[DefaultSchemaTableNameOrOptions['schema']]['Views'])[TableName] extends {
			Row: infer R;
		}
		? R
		: never
	: DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
		? (DefaultSchema['Tables'] & DefaultSchema['Views'])[DefaultSchemaTableNameOrOptions] extends {
				Row: infer R;
			}
			? R
			: never
		: never;

export type TablesInsert<
	DefaultSchemaTableNameOrOptions extends
		| keyof DefaultSchema['Tables']
		| { schema: keyof Database },
	TableName extends DefaultSchemaTableNameOrOptions extends {
		schema: keyof Database;
	}
		? keyof Database[DefaultSchemaTableNameOrOptions['schema']]['Tables']
		: never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
	? Database[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
			Insert: infer I;
		}
		? I
		: never
	: DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
		? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
				Insert: infer I;
			}
			? I
			: never
		: never;

export type TablesUpdate<
	DefaultSchemaTableNameOrOptions extends
		| keyof DefaultSchema['Tables']
		| { schema: keyof Database },
	TableName extends DefaultSchemaTableNameOrOptions extends {
		schema: keyof Database;
	}
		? keyof Database[DefaultSchemaTableNameOrOptions['schema']]['Tables']
		: never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
	? Database[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
			Update: infer U;
		}
		? U
		: never
	: DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
		? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
				Update: infer U;
			}
			? U
			: never
		: never;

export type Enums<
	DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums'] | { schema: keyof Database },
	EnumName extends DefaultSchemaEnumNameOrOptions extends {
		schema: keyof Database;
	}
		? keyof Database[DefaultSchemaEnumNameOrOptions['schema']]['Enums']
		: never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof Database }
	? Database[DefaultSchemaEnumNameOrOptions['schema']]['Enums'][EnumName]
	: DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums']
		? DefaultSchema['Enums'][DefaultSchemaEnumNameOrOptions]
		: never;

export type CompositeTypes<
	PublicCompositeTypeNameOrOptions extends
		| keyof DefaultSchema['CompositeTypes']
		| { schema: keyof Database },
	CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
		schema: keyof Database;
	}
		? keyof Database[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes']
		: never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof Database }
	? Database[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes'][CompositeTypeName]
	: PublicCompositeTypeNameOrOptions extends keyof DefaultSchema['CompositeTypes']
		? DefaultSchema['CompositeTypes'][PublicCompositeTypeNameOrOptions]
		: never;

export const Constants = {
	graphql_public: {
		Enums: {}
	},
	public: {
		Enums: {}
	}
} as const;
