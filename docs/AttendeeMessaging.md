# Attendee messaging

The app stores conversations on device and sends them through `AttendeeMessageTransport`. `LocalDemoMessageTransport` is the implementation that ships in this package. It writes `messages.json` next to the profile and never opens a socket. A message saved there was not delivered to anyone else. The chat says so.

A later service adopts the same protocol. The screens do not need to change. This document is the contract that service would implement. There is no server in this repository.

## Who can message

Both people have to be discoverable and both have to turn on messaging. A block on either side stops a send. The client checks this before composing, and the server has to check it again. Hidden email, phone, and social links are not part of messaging and are not returned by the directory API.

## Local demo

| Piece | Behavior |
| --- | --- |
| `LocalDemoMessageTransport` | Persists conversations, messages, blocks, and reports as JSON. |
| Delivery | A send is `queued`, then `demoOnDevice`. It never becomes `acceptedByService`. |
| Notice | Each send appends a line from `conferencekit.demo-transport` saying the message stayed on the device. |
| `receiveDemo` | Test and sample-thread helper. It inserts a local row. It is not a network receive. |
| Reports | Stored on device. Nothing is filed with a moderator. |

## Directory

`GET /v1/conferences/{conferenceID}/attendees`

Returns discoverable attendees only. Each object is the public projection: name, role, company, bio, ticket, and avatar. Email, phone, and social links are present only when that attendee’s flag is true. Everyone else is omitted, not returned with empty contact fields and a hidden id.

`GET /v1/conferences/{conferenceID}/attendees/{attendeeID}`

404 when the person is not discoverable.

## Profile

`PUT /v1/me`

Body is the same attendee object the manifest uses, including privacy flags and `messagingConsent`. The server stores the full record and serves other clients the public projection only.

## Conversations

`GET /v1/conversations`

Conversations for the signed-in attendee, newest first, with an unread count.

`POST /v1/conversations`

Body: `{ "recipientID": "..." }`. 403 with a reason (`not_discoverable`, `no_consent`, `blocked`) when policy fails. The response is the conversation id, which is stable for the pair.

`GET /v1/conversations/{conversationID}/messages?after={iso8601}`

Pages of messages. Demo notices are a client concern and are not stored on the server.

`POST /v1/conversations/{conversationID}/messages`

Body: `{ "body": "...", "clientID": "..." }`. `clientID` is the idempotency key. The server returns the stored message with `delivery: "acceptedByService"`. A duplicate `clientID` returns the original message.

`POST /v1/conversations/{conversationID}/read`

Body: `{ "readAt": "..." }`.

## Blocks and reports

`PUT /v1/blocks/{attendeeID}` and `DELETE /v1/blocks/{attendeeID}`

A block hides later messages in both directions. Existing rows can stay on each device.

`POST /v1/reports`

Body: `{ "attendeeID": "...", "reason": "spam | harassment | other", "note": "..." }`. The server queues the report for a human. The client does not show the other person that they were reported.

## Realtime and push

`GET /v1/stream` is a WebSocket authenticated with the same session. Events:

- `message.created` with conversation id and message id. The body can be included for an active socket. A client that missed events refetches with `after`.
- `message.accepted` when the server has stored an outgoing message.
- `conversation.read` when the other person reads, if product wants receipts later. The first version can skip receipts.

Push is APNs (and the watch and Mac equivalents through the same token). The payload is `{ "conversationID", "messageID" }` and nothing else. The device fetches the message over the authenticated API. A lock-screen notification can say “New conference message” without the text, unless the person has opted into previews.

The server needs the attendee’s push token, registered with `PUT /v1/devices`. Deleting the account or signing out deletes the token.

## Auth

The host app signs the attendee in. This package does not. Requests carry a bearer token the server can map to one attendee id. The token’s attendee has to match `sender` on every write.

## What stays out of this package

A production process, accounts, push credentials, moderation tools, and any path that delivers a message to another person’s device.
