# 0005 — Non-ASCII attachment names are RFC 2047 encoded-words, the way Gmail sends them

Status: accepted (2026-10-13). Decided in [omakindle#17](https://github.com/tiilyat/omakindle/issues/17) during the live acceptance walk.

## Decision
When the book's basename contains a byte outside printable ASCII, or `"` or `\`, both the `name=` and `filename=` parameters of the attachment carry RFC 2047 B-encoded words (`=?UTF-8?B?…?=`), chunked at UTF-8 character boundaries so every word stays under 75 characters. ASCII names are sent as a plain quoted string. The attachment `Content-Type` follows the extension (`application/epub+zip` for EPUB) instead of `application/octet-stream`.

## Drivers
- Amazon's email path reads encoded-words and ignores RFC 2231 `filename*`: a message with `filename*` arrived with the ASCII fallback as its title.
- The e-reader could not open books sent as `application/octet-stream` with an underscore name, while the same file sent from Gmail opened; Gmail's raw message differs only in the encoded-word name and the typed `Content-Type`. Mirroring Gmail is the one layout proven to work.
- The Kindle shows the attachment name as the document title, so the name must survive the trip readable.

## Alternatives rejected
- Underscores for every non-ASCII byte (the first implementation): the title became a row of underscores.
- RFC 2231 `filename*=UTF-8''…` (the standards-conformant parameter): Amazon ignores it on the email path.
- ICU transliteration to Latin: readable but lossy, and unnecessary once encoded-words proved to work.

## Consequences
- Encoded-words inside a quoted-string parameter violate RFC 2047 §5; the message is shaped for Amazon's parser, not for the standard.
- A change in Amazon's parser shows up as an unreadable title or an unopenable book, and is detectable only by a real send.
