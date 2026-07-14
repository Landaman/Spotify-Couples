export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface Database {
	graphql_public: {
		Tables: Record<never, never>;
		Views: Record<never, never>;
		Functions: {
			graphql: {
				Args: {
					extensions?: Json;
					operationName?: string;
					query?: string;
					variables?: Json;
				};
				Returns: Json;
			};
		};
		Enums: Record<never, never>;
		CompositeTypes: Record<never, never>;
	};
	public: {
		Tables: {
			albums: {
				Row: {
					album_type: Database['public']['Enums']['album_type'];
					artist_ids: string[];
					id: string;
					name: string;
					picture_url: string | null;
					release_date: string;
					release_date_precision: Database['public']['Enums']['album_release_date_precision'];
				};
				Insert: {
					album_type: Database['public']['Enums']['album_type'];
					artist_ids: string[];
					id: string;
					name: string;
					picture_url?: string | null;
					release_date: string;
					release_date_precision: Database['public']['Enums']['album_release_date_precision'];
				};
				Update: {
					album_type?: Database['public']['Enums']['album_type'];
					artist_ids?: string[];
					id?: string;
					name?: string;
					picture_url?: string | null;
					release_date?: string;
					release_date_precision?: Database['public']['Enums']['album_release_date_precision'];
				};
				Relationships: [];
			};
			artists: {
				Row: {
					genres: string[];
					id: string;
					name: string;
					picture_url: string | null;
				};
				Insert: {
					genres: string[];
					id: string;
					name: string;
					picture_url?: string | null;
				};
				Update: {
					genres?: string[];
					id?: string;
					name?: string;
					picture_url?: string | null;
				};
				Relationships: [];
			};
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
					spotify_played_context_uri: string | null;
					track_id: string;
					user_id: string;
				};
				Insert: {
					id?: string;
					played_date_time: string;
					spotify_played_context_uri?: string | null;
					track_id: string;
					user_id: string;
				};
				Update: {
					id?: string;
					played_date_time?: string;
					spotify_played_context_uri?: string | null;
					track_id?: string;
					user_id?: string;
				};
				Relationships: [
					{
						foreignKeyName: 'plays_track_id_fkey';
						columns: ['track_id'];
						isOneToOne: false;
						referencedRelation: 'tracks';
						referencedColumns: ['id'];
					}
				];
			};
			tracks: {
				Row: {
					album_id: string;
					artist_ids: string[];
					disc_number: number;
					duration_ms: number;
					explicit: boolean;
					id: string;
					name: string;
					track_number: number;
				};
				Insert: {
					album_id: string;
					artist_ids: string[];
					disc_number: number;
					duration_ms: number;
					explicit: boolean;
					id: string;
					name: string;
					track_number: number;
				};
				Update: {
					album_id?: string;
					artist_ids?: string[];
					disc_number?: number;
					duration_ms?: number;
					explicit?: boolean;
					id?: string;
					name?: string;
					track_number?: number;
				};
				Relationships: [
					{
						foreignKeyName: 'tracks_album_id_fkey';
						columns: ['album_id'];
						isOneToOne: false;
						referencedRelation: 'albums';
						referencedColumns: ['id'];
					}
				];
			};
		};
		Views: Record<never, never>;
		Functions: {
			get_or_create_pairing_code: {
				Args: never;
				Returns: {
					code: string;
					expires_at: string;
					owner_id: string;
				};
				SetofOptions: {
					from: '*';
					to: 'pairing_codes';
					isOneToOne: true;
					isSetofReturn: false;
				};
			};
			get_partner_id:
				{ Args: never; Returns: string } | { Args: { search_uuid: string }; Returns: string };
			get_partner_profile: {
				Args: never;
				Returns: Database['public']['CompositeTypes']['profile'];
				SetofOptions: {
					from: '*';
					to: 'profile';
					isOneToOne: true;
					isSetofReturn: false;
				};
			};
			pair_with_code: { Args: { pairing_code: string }; Returns: undefined };
			process_spotify_refresh_token: {
				Args: { refresh_token: string };
				Returns: boolean;
			};
			read_plays_for_user_if_needed: { Args: never; Returns: boolean };
			user_needs_play_refresh: { Args: never; Returns: boolean };
		};
		Enums: {
			album_release_date_precision: 'year' | 'month' | 'day';
			album_type: 'album' | 'single' | 'compilation';
		};
		CompositeTypes: {
			profile: {
				id: string | null;
				name: string | null;
				spotify_id: string | null;
				picture_url: string | null;
			};
		};
	};
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>;

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, 'public'>];

export type Tables<
	DefaultSchemaTableNameOrOptions extends
		| keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
		| { schema: keyof DatabaseWithoutInternals },
	TableName extends (DefaultSchemaTableNameOrOptions extends {
		schema: keyof DatabaseWithoutInternals;
	}
		? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
				DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])
		: never) = never
> = DefaultSchemaTableNameOrOptions extends {
	schema: keyof DatabaseWithoutInternals;
}
	? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
			DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])[TableName] extends {
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
		keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
	TableName extends (DefaultSchemaTableNameOrOptions extends {
		schema: keyof DatabaseWithoutInternals;
	}
		? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
		: never) = never
> = DefaultSchemaTableNameOrOptions extends {
	schema: keyof DatabaseWithoutInternals;
}
	? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
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
		keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
	TableName extends (DefaultSchemaTableNameOrOptions extends {
		schema: keyof DatabaseWithoutInternals;
	}
		? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
		: never) = never
> = DefaultSchemaTableNameOrOptions extends {
	schema: keyof DatabaseWithoutInternals;
}
	? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
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
	DefaultSchemaEnumNameOrOptions extends
		keyof DefaultSchema['Enums'] | { schema: keyof DatabaseWithoutInternals },
	EnumName extends (DefaultSchemaEnumNameOrOptions extends {
		schema: keyof DatabaseWithoutInternals;
	}
		? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums']
		: never) = never
> = DefaultSchemaEnumNameOrOptions extends {
	schema: keyof DatabaseWithoutInternals;
}
	? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums'][EnumName]
	: DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums']
		? DefaultSchema['Enums'][DefaultSchemaEnumNameOrOptions]
		: never;

export type CompositeTypes<
	PublicCompositeTypeNameOrOptions extends
		keyof DefaultSchema['CompositeTypes'] | { schema: keyof DatabaseWithoutInternals },
	CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
		schema: keyof DatabaseWithoutInternals;
	}
		? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes']
		: never) = never
> = PublicCompositeTypeNameOrOptions extends {
	schema: keyof DatabaseWithoutInternals;
}
	? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes'][CompositeTypeName]
	: PublicCompositeTypeNameOrOptions extends keyof DefaultSchema['CompositeTypes']
		? DefaultSchema['CompositeTypes'][PublicCompositeTypeNameOrOptions]
		: never;

export const Constants = {
	graphql_public: {
		Enums: {}
	},
	public: {
		Enums: {
			album_release_date_precision: ['year', 'month', 'day'],
			album_type: ['album', 'single', 'compilation']
		}
	}
} as const;
