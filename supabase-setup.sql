-- Run this SQL in your Supabase SQL editor (https://app.supabase.com)
-- Dashboard → SQL Editor → New query → paste and run
-- This script is safe to run multiple times (uses IF NOT EXISTS / DROP IF EXISTS)

-- ─── 1. Profiles ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id                      UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username                TEXT    NOT NULL DEFAULT 'StudyBuddy',
  avatar_index            INTEGER NOT NULL DEFAULT 0,
  xp                      INTEGER NOT NULL DEFAULT 0,
  gems                    INTEGER NOT NULL DEFAULT 500,
  streak                  INTEGER NOT NULL DEFAULT 0,
  last_played_date        TEXT,
  had_perfect_score       BOOLEAN NOT NULL DEFAULT false,
  had_fast_finish         BOOLEAN NOT NULL DEFAULT false,
  total_quizzes_completed INTEGER NOT NULL DEFAULT 0,
  sound_enabled           BOOLEAN NOT NULL DEFAULT true,
  plan                    TEXT    NOT NULL DEFAULT 'free',
  pdf_count               INTEGER NOT NULL DEFAULT 0,
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop and recreate all policies to allow safe re-runs
DROP POLICY IF EXISTS "Users can insert own profile"                        ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile"                          ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile"                        ON public.profiles;
DROP POLICY IF EXISTS "Service role reads all for leaderboard"              ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can read all profiles for leaderboard" ON public.profiles;

-- Users can insert/upsert their own profile row
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can read their own profile
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- All logged-in users can read all profiles (powers the leaderboard)
CREATE POLICY "Authenticated users can read all profiles for leaderboard"
  ON public.profiles FOR SELECT USING (auth.uid() IS NOT NULL);

-- Auto-create a profile row whenever a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- ─── 2. Projects ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.projects (
  id                      TEXT    PRIMARY KEY,
  user_id                 UUID    REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name                    TEXT    NOT NULL,
  pdf_text                TEXT    NOT NULL DEFAULT '',
  upload_date             TEXT    NOT NULL DEFAULT '',
  num_levels              INTEGER NOT NULL DEFAULT 10,
  current_level           INTEGER NOT NULL DEFAULT 1,
  completed               BOOLEAN NOT NULL DEFAULT false,
  master_questions        JSONB   NOT NULL DEFAULT '[]',
  master_hangman_words    JSONB   NOT NULL DEFAULT '[]',
  questions_per_level     INTEGER NOT NULL DEFAULT 10,
  hangman_words_per_level INTEGER NOT NULL DEFAULT 7,
  total_questions         INTEGER NOT NULL DEFAULT 0,
  levels                  JSONB   NOT NULL DEFAULT '[]',
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own projects" ON public.projects;
CREATE POLICY "Users can CRUD own projects"
  ON public.projects FOR ALL USING (auth.uid() = user_id);


-- ─── 3. Payments (dormant — for future use) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payments (
  id                  TEXT    PRIMARY KEY,
  user_id             UUID    REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  razorpay_order_id   TEXT    NOT NULL,
  razorpay_payment_id TEXT,
  amount              INTEGER NOT NULL,
  currency            TEXT    NOT NULL DEFAULT 'INR',
  status              TEXT    NOT NULL DEFAULT 'created',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own payments"   ON public.payments;
DROP POLICY IF EXISTS "Service role manages payments" ON public.payments;
CREATE POLICY "Users can read own payments"   ON public.payments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Service role manages payments" ON public.payments FOR ALL   USING (true);


-- ─── 4. Leaderboard view (top 50 by XP) ─────────────────────────────────────
CREATE OR REPLACE VIEW public.leaderboard AS
  SELECT id, username, xp, avatar_index, plan
  FROM public.profiles
  ORDER BY xp DESC
  LIMIT 50;
