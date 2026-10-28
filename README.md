# Reaper

A small, read-only command-line tool for Tumblr. Given a blog and a source blog, it lists every post
on the blog that was reblogged from that source.

It uses only the official Tumblr API v2 (`api.tumblr.com`) with a registered application key, and
optionally an OAuth2 user token so that it sees the same posts the logged-in account sees. It never
writes anything: no posts, likes, follows or reblogs.

## Why it has to read every post

The API has no filter for "posts reblogged from blog X". The reblog source is a field on each post
(`reblogged_from_name`, returned when `reblog_info=true`), so the only way to find the matches is to
enumerate the blog's posts and keep the ones whose source matches. Reaper does that as cheaply as the
API allows:

| Parameter | Effect |
|---|---|
| `limit=50` | 50 posts per request (the documentation says 20, the API returns 50) |
| `filter=text` | text-only bodies, about a quarter of the default payload |
| `reblog_info=true` | adds the reblog source fields to each post |
| `before=<timestamp>` | paging by timestamp, which has no cap unlike `offset` |

A blog with 100,000 posts is about 2,000 requests. With the default application limits of 1,000
requests per hour that is several hours per pass, which is why this project asks Tumblr for a higher
limit.

## Usage

```bash
# one-time: put your OAuth consumer key in a file
mkdir -p ~/.config/reaper && echo YOUR_CONSUMER_KEY > ~/.config/reaper/tumblr_key

# find every post on geekgirles reblogged from smallpwbbles
./tumblr_find_reblogs.sh geekgirles smallpwbbles
```

Matching post URLs are printed one per line. A `429` from the API pauses the scan for a minute and
retries; a short page ends it.

### Optional: user token

To see dashboard-only blogs or mature content that your own account can see, authorize the app once
and store the token:

```bash
echo YOUR_CONSUMER_SECRET > ~/.config/reaper/tumblr_secret
# open the /oauth2/authorize URL for your app, click Allow, copy the `code` from the redirect URL
./tumblr_oauth.sh THE_CODE
```

`tumblr_find_reblogs.sh` picks the token up automatically, refreshes it before each run and again if
a request returns `401`.

## Files

- `tumblr_find_reblogs.sh`: the scan.
- `tumblr_oauth.sh`: OAuth2 code exchange and token refresh.

Credentials live in `~/.config/reaper/` and are never committed.

## Rate limits

Reaper runs on one machine with one consumer key and makes GET requests only. All requests carry the
application's key, so Tumblr can attribute and limit them.
