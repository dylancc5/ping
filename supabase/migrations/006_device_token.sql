-- Migration 006: Add device_token column to profiles
-- Stores the APNs device token for push notification delivery.
-- Written by the score-contacts Edge Function after each nudge is created.
-- Updated by iOS via SupabaseService.saveDeviceToken() on app launch / token refresh.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS device_token TEXT;
