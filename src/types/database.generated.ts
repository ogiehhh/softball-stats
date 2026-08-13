export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.15"
  }
  public: {
    Tables: {
      admin_users: {
        Row: {
          created_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          user_id?: string
        }
        Relationships: []
      }
      game_lineup: {
        Row: {
          batting_order: number
          created_at: string
          game_id: string
          player_id: string
          season_id: string
        }
        Insert: {
          batting_order: number
          created_at?: string
          game_id: string
          player_id: string
          season_id: string
        }
        Update: {
          batting_order?: number
          created_at?: string
          game_id?: string
          player_id?: string
          season_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_lineup_game_id_season_id_fkey"
            columns: ["game_id", "season_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["id", "season_id"]
          },
          {
            foreignKeyName: "game_lineup_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_lineup_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "season_batting_stats"
            referencedColumns: ["player_id"]
          },
          {
            foreignKeyName: "game_lineup_season_id_player_id_fkey"
            columns: ["season_id", "player_id"]
            isOneToOne: false
            referencedRelation: "season_players"
            referencedColumns: ["season_id", "player_id"]
          },
        ]
      }
      game_states: {
        Row: {
          first_base_player_id: string | null
          game_id: string
          inning: number
          next_batter_order: number
          outs: number
          second_base_player_id: string | null
          third_base_player_id: string | null
          updated_at: string
        }
        Insert: {
          first_base_player_id?: string | null
          game_id: string
          inning?: number
          next_batter_order?: number
          outs?: number
          second_base_player_id?: string | null
          third_base_player_id?: string | null
          updated_at?: string
        }
        Update: {
          first_base_player_id?: string | null
          game_id?: string
          inning?: number
          next_batter_order?: number
          outs?: number
          second_base_player_id?: string | null
          third_base_player_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_states_game_id_first_base_player_id_fkey"
            columns: ["game_id", "first_base_player_id"]
            isOneToOne: false
            referencedRelation: "game_lineup"
            referencedColumns: ["game_id", "player_id"]
          },
          {
            foreignKeyName: "game_states_game_id_fkey"
            columns: ["game_id"]
            isOneToOne: true
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_states_game_id_second_base_player_id_fkey"
            columns: ["game_id", "second_base_player_id"]
            isOneToOne: false
            referencedRelation: "game_lineup"
            referencedColumns: ["game_id", "player_id"]
          },
          {
            foreignKeyName: "game_states_game_id_third_base_player_id_fkey"
            columns: ["game_id", "third_base_player_id"]
            isOneToOne: false
            referencedRelation: "game_lineup"
            referencedColumns: ["game_id", "player_id"]
          },
        ]
      }
      games: {
        Row: {
          archived_at: string | null
          archived_by: string | null
          created_at: string
          id: string
          opponent: string
          opponent_score: number | null
          played_at: string
          season_id: string
          status: Database["public"]["Enums"]["game_status"]
          team_score: number | null
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          archived_by?: string | null
          created_at?: string
          id?: string
          opponent: string
          opponent_score?: number | null
          played_at: string
          season_id: string
          status?: Database["public"]["Enums"]["game_status"]
          team_score?: number | null
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          archived_by?: string | null
          created_at?: string
          id?: string
          opponent?: string
          opponent_score?: number | null
          played_at?: string
          season_id?: string
          status?: Database["public"]["Enums"]["game_status"]
          team_score?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "games_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      leagues: {
        Row: {
          active: boolean
          archived_at: string | null
          archived_by: string | null
          created_at: string
          id: string
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          archived_at?: string | null
          archived_by?: string | null
          created_at?: string
          id?: string
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          archived_at?: string | null
          archived_by?: string | null
          created_at?: string
          id?: string
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      plate_appearances: {
        Row: {
          created_at: string
          game_id: string
          id: string
          inning: number
          outs_before: number
          outs_recorded: number
          player_id: string
          rbi: number
          result: Database["public"]["Enums"]["plate_appearance_result"]
          sequence_no: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          game_id: string
          id?: string
          inning: number
          outs_before: number
          outs_recorded?: number
          player_id: string
          rbi?: number
          result: Database["public"]["Enums"]["plate_appearance_result"]
          sequence_no: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          game_id?: string
          id?: string
          inning?: number
          outs_before?: number
          outs_recorded?: number
          player_id?: string
          rbi?: number
          result?: Database["public"]["Enums"]["plate_appearance_result"]
          sequence_no?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "plate_appearances_game_id_fkey"
            columns: ["game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plate_appearances_game_id_player_id_fkey"
            columns: ["game_id", "player_id"]
            isOneToOne: false
            referencedRelation: "game_lineup"
            referencedColumns: ["game_id", "player_id"]
          },
          {
            foreignKeyName: "plate_appearances_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plate_appearances_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "season_batting_stats"
            referencedColumns: ["player_id"]
          },
        ]
      }
      players: {
        Row: {
          active: boolean
          created_at: string
          display_name: string | null
          first_name: string
          id: string
          last_name: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          display_name?: string | null
          first_name: string
          id?: string
          last_name?: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          display_name?: string | null
          first_name?: string
          id?: string
          last_name?: string
          updated_at?: string
        }
        Relationships: []
      }
      runner_advancements: {
        Row: {
          created_at: string
          ending_base: Database["public"]["Enums"]["base_destination"]
          id: string
          plate_appearance_id: string
          player_id: string
          starting_base: Database["public"]["Enums"]["base_origin"]
        }
        Insert: {
          created_at?: string
          ending_base: Database["public"]["Enums"]["base_destination"]
          id?: string
          plate_appearance_id: string
          player_id: string
          starting_base: Database["public"]["Enums"]["base_origin"]
        }
        Update: {
          created_at?: string
          ending_base?: Database["public"]["Enums"]["base_destination"]
          id?: string
          plate_appearance_id?: string
          player_id?: string
          starting_base?: Database["public"]["Enums"]["base_origin"]
        }
        Relationships: [
          {
            foreignKeyName: "runner_advancements_plate_appearance_id_fkey"
            columns: ["plate_appearance_id"]
            isOneToOne: false
            referencedRelation: "plate_appearances"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runner_advancements_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runner_advancements_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "season_batting_stats"
            referencedColumns: ["player_id"]
          },
        ]
      }
      season_players: {
        Row: {
          created_at: string
          player_id: string
          season_id: string
        }
        Insert: {
          created_at?: string
          player_id: string
          season_id: string
        }
        Update: {
          created_at?: string
          player_id?: string
          season_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "season_players_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "season_players_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "season_batting_stats"
            referencedColumns: ["player_id"]
          },
          {
            foreignKeyName: "season_players_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      seasons: {
        Row: {
          active: boolean
          archived_at: string | null
          archived_by: string | null
          completed_at: string | null
          completed_by: string | null
          created_at: string
          end_date: string | null
          id: string
          league_id: string
          name: string
          start_date: string | null
          updated_at: string
        }
        Insert: {
          active?: boolean
          archived_at?: string | null
          archived_by?: string | null
          completed_at?: string | null
          completed_by?: string | null
          created_at?: string
          end_date?: string | null
          id?: string
          league_id: string
          name: string
          start_date?: string | null
          updated_at?: string
        }
        Update: {
          active?: boolean
          archived_at?: string | null
          archived_by?: string | null
          completed_at?: string | null
          completed_by?: string | null
          created_at?: string
          end_date?: string | null
          id?: string
          league_id?: string
          name?: string
          start_date?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "seasons_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      season_batting_stats: {
        Row: {
          at_bats: number | null
          batting_average: number | null
          doubles: number | null
          fielders_choice: number | null
          games: number | null
          hit_by_pitch: number | null
          hits: number | null
          home_runs: number | null
          league_id: string | null
          league_name: string | null
          league_slug: string | null
          on_base_percentage: number | null
          ops: number | null
          plate_appearances: number | null
          player_id: string | null
          player_name: string | null
          rbi: number | null
          reached_on_error: number | null
          runs: number | null
          sacrifice_flies: number | null
          season_id: string | null
          season_name: string | null
          singles: number | null
          slugging_percentage: number | null
          strikeouts: number | null
          total_bases: number | null
          triples: number | null
          walks: number | null
        }
        Relationships: [
          {
            foreignKeyName: "season_players_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seasons_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      add_existing_player_to_season: {
        Args: { p_player_id: string; p_season_id: string }
        Returns: string
      }
      archive_game: { Args: { p_game_id: string }; Returns: string }
      archive_league: { Args: { p_league_id: string }; Returns: string }
      archive_season: { Args: { p_season_id: string }; Returns: string }
      complete_season: { Args: { p_season_id: string }; Returns: string }
      create_game_with_lineup: {
        Args: {
          p_league_id: string
          p_lineup_player_ids: string[]
          p_opponent: string
          p_played_at: string
          p_season_id: string
        }
        Returns: string
      }
      create_league: { Args: { p_name: string }; Returns: string }
      create_player_for_season: {
        Args: { p_display_name: string; p_season_id: string }
        Returns: string
      }
      create_season: {
        Args: {
          p_end_date?: string
          p_league_id: string
          p_name: string
          p_start_date?: string
        }
        Returns: string
      }
      finish_game: {
        Args: { p_expected_state_updated_at: string; p_game_id: string }
        Returns: string
      }
      record_plate_appearance: {
        Args: {
          p_expected_state_updated_at: string
          p_game_id: string
          p_outs_recorded: number
          p_rbi: number
          p_result: Database["public"]["Enums"]["plate_appearance_result"]
          p_runner_outcomes: Json
        }
        Returns: string
      }
      reopen_season: { Args: { p_season_id: string }; Returns: string }
      remove_player_from_season: {
        Args: { p_player_id: string; p_season_id: string }
        Returns: string
      }
      restore_game: { Args: { p_game_id: string }; Returns: string }
      restore_league: { Args: { p_league_id: string }; Returns: string }
      restore_season: { Args: { p_season_id: string }; Returns: string }
      undo_last_plate_appearance: {
        Args: { p_expected_state_updated_at: string; p_game_id: string }
        Returns: string
      }
    }
    Enums: {
      base_destination: "first" | "second" | "third" | "home" | "out"
      base_origin: "batter" | "first" | "second" | "third"
      game_status: "draft" | "in_progress" | "completed"
      plate_appearance_result:
        | "single"
        | "double"
        | "triple"
        | "home_run"
        | "walk"
        | "hit_by_pitch"
        | "strikeout"
        | "groundout"
        | "flyout"
        | "lineout"
        | "popout"
        | "sacrifice_fly"
        | "fielders_choice"
        | "reached_on_error"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      base_destination: ["first", "second", "third", "home", "out"],
      base_origin: ["batter", "first", "second", "third"],
      game_status: ["draft", "in_progress", "completed"],
      plate_appearance_result: [
        "single",
        "double",
        "triple",
        "home_run",
        "walk",
        "hit_by_pitch",
        "strikeout",
        "groundout",
        "flyout",
        "lineout",
        "popout",
        "sacrifice_fly",
        "fielders_choice",
        "reached_on_error",
      ],
    },
  },
} as const
