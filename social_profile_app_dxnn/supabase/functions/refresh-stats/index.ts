// @ts-nocheck
import { createClient } from 'npm:@supabase/supabase-js@2.58.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const CRON_SECRET = Deno.env.get('CRON_SECRET');

const YOUTUBE_API_KEY = Deno.env.get('YOUTUBE_API_KEY');
const YOUTUBE_CHANNEL_ID = Deno.env.get('YOUTUBE_CHANNEL_ID') || 'UChDhfhF0xFrnVtdPbQPzhTg';

const META_PAGE_ID = Deno.env.get('META_PAGE_ID') || Deno.env.get('FACEBOOK_PAGE_ID');
const META_PAGE_TOKEN = Deno.env.get('META_PAGE_TOKEN') || Deno.env.get('FACEBOOK_PAGE_TOKEN');
const IG_USER_ID = Deno.env.get('IG_USER_ID') || Deno.env.get('INSTAGRAM_BUSINESS_ACCOUNT_ID');
const IG_TOKEN = Deno.env.get('IG_TOKEN') || Deno.env.get('INSTAGRAM_ACCESS_TOKEN');

const FACEBOOK_PAGE_NAME = Deno.env.get('FACEBOOK_PAGE_NAME') || 'daxenmoroccoOfficial';
const INSTAGRAM_USERNAME = Deno.env.get('INSTAGRAM_USERNAME') || 'daxenmorocco.llc';

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

function truncateError(error: unknown) {
  if (error instanceof Error) {
    return error.message.slice(0, 500);
  }
  return String(error).slice(0, 500);
}

async function fetchWithTimeout(url: string, init: RequestInit = {}, timeoutMs = 8000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { ...init, signal: controller.signal });
    return response;
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchYoutubeFollowers() {
  if (YOUTUBE_API_KEY && YOUTUBE_CHANNEL_ID) {
    try {
      const url = `https://www.googleapis.com/youtube/v3/channels?part=statistics&id=${encodeURIComponent(YOUTUBE_CHANNEL_ID)}&key=${encodeURIComponent(YOUTUBE_API_KEY)}`;
      const res = await fetchWithTimeout(url);
      if (res.ok) {
        const data = await res.json();
        const item = data?.items?.[0];
        const countStr = item?.statistics?.subscriberCount;
        const hidden = item?.statistics?.hiddenSubscriberCount === true;
        if (!hidden && countStr) {
          const count = Number(countStr);
          if (Number.isFinite(count) && count >= 0) {
            return count;
          }
        }
      }
    } catch (_) {
      // fall through
    }
  }

  // Fallback: scrape public channel page
  try {
    const url = `https://www.youtube.com/channel/${encodeURIComponent(YOUTUBE_CHANNEL_ID)}`;
    const res = await fetchWithTimeout(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    });
    if (!res.ok) {
      throw new Error(`youtube_http_${res.status}`);
    }
    const html = await res.text();
    const patterns = [
      /"subscriberCountText"\s*:\s*\{"simpleText"\s*:\s*"([0-9.,\sKkMm]+)"/,
      /([0-9]{1,3}(?:[.,\s][0-9]{3})+)\s+abonnés/i,
      /([0-9]+(?:[.,][0-9]+)?[KkMm])\s+abonnés/i,
    ];
    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        let numStr = match[1].replace(/\s/g, '');
        if (/[Kk]$/.test(numStr)) {
          const n = parseFloat(numStr.replace(/[Kk]/, '').replace(',', '.'));
          if (Number.isFinite(n)) return Math.round(n * 1000);
        }
        if (/[Mm]$/.test(numStr)) {
          const n = parseFloat(numStr.replace(/[Mm]/, '').replace(',', '.'));
          if (Number.isFinite(n)) return Math.round(n * 1000000);
        }
        numStr = numStr.replace(/[.,]/g, '');
        const count = Number(numStr);
        if (Number.isFinite(count) && count >= 0) {
          return count;
        }
      }
    }
    throw new Error('youtube_parse_failed');
  } catch (error) {
    throw error;
  }
}

async function fetchFacebookFollowers() {
  // Try Graph API first if configured
  if (META_PAGE_ID && META_PAGE_TOKEN) {
    try {
      const url = `https://graph.facebook.com/v26.0/${encodeURIComponent(META_PAGE_ID)}?fields=followers_count,fan_count&access_token=${encodeURIComponent(META_PAGE_TOKEN)}`;
      const res = await fetchWithTimeout(url);
      if (res.ok) {
        const data = await res.json();
        const count = Number(data?.followers_count ?? data?.fan_count);
        if (Number.isFinite(count) && count >= 0) {
          return count;
        }
      }
    } catch (_) {
      // fall through to scraping
    }
  }

  // Fallback 1: mbasic.facebook.com (much easier to parse)
  try {
    const url = `https://mbasic.facebook.com/${encodeURIComponent(FACEBOOK_PAGE_NAME)}`;
    const res = await fetchWithTimeout(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9',
      },
    });
    if (res.ok) {
      const html = await res.text();
      const patterns = [
        /([0-9]{1,3}(?:[.,\s][0-9]{3})+)\s+(?:abonnés|followers|personnes?\s+suivent)/i,
        /([0-9]+)\s+(?:abonnés|followers)/i,
        /\"followers\"\s*:\s*([0-9]+)/i,
      ];
      for (const pattern of patterns) {
        const match = html.match(pattern);
        if (match && match[1]) {
          const numStr = match[1].replace(/[.,\s]/g, '');
          const count = Number(numStr);
          if (Number.isFinite(count) && count >= 0) {
            return count;
          }
        }
      }
    }
  } catch (_) {
    // fall through
  }

  // Fallback 2: www.facebook.com with stronger headers
  try {
    const url = `https://www.facebook.com/${encodeURIComponent(FACEBOOK_PAGE_NAME)}`;
    const res = await fetchWithTimeout(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    });
    if (!res.ok) {
      throw new Error(`facebook_http_${res.status}`);
    }
    const html = await res.text();
    const patterns = [
      /([0-9]{1,3}(?:[.,\s][0-9]{3})+)\s+(?:abonnés|followers|J'aime|likes|personnes?\s+suivent)/i,
      /\"follower_count\"\s*:\s*([0-9]+)/,
      /followers_count[^0-9]*([0-9]+)/i,
      /\"pageFansCount\"[^0-9]*([0-9]+)/i,
      /\"fan_count\"\s*:\s*([0-9]+)/,
      /\"edge_followed_by\"\s*:\s*\{\"count\"\s*:\s*([0-9]+)/,
    ];
    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const numStr = match[1].replace(/[.,\s]/g, '');
        const count = Number(numStr);
        if (Number.isFinite(count) && count >= 0) {
          return count;
        }
      }
    }
    throw new Error('facebook_parse_failed');
  } catch (error) {
    throw error;
  }
}

async function fetchInstagramFollowers() {
  // Try Graph API first if configured
  if (IG_USER_ID && IG_TOKEN) {
    const url = `https://graph.facebook.com/v26.0/${encodeURIComponent(IG_USER_ID)}?fields=followers_count&access_token=${encodeURIComponent(IG_TOKEN)}`;
    const res = await fetchWithTimeout(url);
    if (res.ok) {
      const data = await res.json();
      const count = Number(data?.followers_count);
      if (Number.isFinite(count)) {
        return count;
      }
    }
  }

  // Fallback: attempt to scrape public profile
  try {
    const url = `https://www.instagram.com/${encodeURIComponent(INSTAGRAM_USERNAME)}/`;
    const res = await fetchWithTimeout(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; SocialProfileBot/1.0)',
        'Accept': 'text/html,application/xhtml+xml',
      },
    });
    if (!res.ok) {
      throw new Error(`instagram_http_${res.status}`);
    }
    const html = await res.text();
    const patterns = [
      /"edge_followed_by":{"count":([0-9]+)/,
      /([0-9]{1,3}(?:[.,][0-9]{3})+)\s+followers/i,
    ];
    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const numStr = match[1].replace(/[.,]/g, '');
        const count = Number(numStr);
        if (Number.isFinite(count) && count >= 0) {
          return count;
        }
      }
    }
    throw new Error('instagram_parse_failed');
  } catch (error) {
    throw error;
  }
}

async function fetchTikTokFollowers() {
  // Leave TikTok as-is per requirements - do not modify
  throw new Error('skipped: tiktok');
}

async function updatePlatform(
  supabase: any,
  platform: 'facebook' | 'youtube' | 'instagram' | 'tiktok',
  fetchFn: () => Promise<number>
) {
  const now = new Date().toISOString();
  try {
    const count = await fetchFn();
    const { error } = await supabase
      .from('social_stats')
      .update({
        followers_count: count,
        source: 'api',
        last_success_at: now,
        last_attempt_at: now,
        last_error: null,
      })
      .eq('platform', platform);
    if (error) throw error;
    console.log(JSON.stringify({ event: 'stats_updated', platform, count }));
    return { platform, ok: true, count };
  } catch (error) {
    const message = truncateError(error);
    console.warn(JSON.stringify({ event: 'stats_update_failed', platform, error: message }));
    try {
      await supabase
        .from('social_stats')
        .update({
          last_attempt_at: now,
          last_error: message,
        })
        .eq('platform', platform);
    } catch (updateError) {
      console.error(JSON.stringify({ event: 'stats_error_update_failed', platform, error: truncateError(updateError) }));
    }
    return { platform, ok: false, error: message };
  }
}

Deno.serve(async (req) => {
  const start = Date.now();
  try {
    // Auth check for cron/service calls
    if (CRON_SECRET) {
      const headerSecret = req.headers.get('x-cron-secret') || req.headers.get('X-Cron-Secret');
      if (headerSecret !== CRON_SECRET) {
        return jsonResponse({ ok: false, error: 'unauthorized' }, 401);
      }
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return jsonResponse({ ok: false, error: 'missing_supabase_config' }, 500);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const results = await Promise.allSettled([
      updatePlatform(supabase, 'facebook', fetchFacebookFollowers),
      updatePlatform(supabase, 'youtube', fetchYoutubeFollowers),
      updatePlatform(supabase, 'instagram', fetchInstagramFollowers),
      // TikTok left untouched as requested
    ]);

    const normalized = results.map((r) => (r.status === 'fulfilled' ? r.value : { ok: false, error: truncateError(r.reason) }));
    const durationMs = Date.now() - start;

    console.log(JSON.stringify({ event: 'refresh_stats_complete', duration_ms: durationMs, results: normalized }));
    return jsonResponse({ ok: true, results: normalized, duration_ms: durationMs }, 200);
  } catch (error) {
    const durationMs = Date.now() - start;
    console.error(JSON.stringify({ event: 'refresh_stats_fatal', duration_ms: durationMs, error: truncateError(error) }));
    return jsonResponse({ ok: false, error: 'internal_error' }, 500);
  }
});
