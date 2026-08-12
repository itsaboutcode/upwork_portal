# Role-aware ActiveAdmin access

Status: Approved

## Problem

Normal users currently land on a separate account page because ActiveAdmin rejects
their role. The intended product journey is for every authenticated application
user to enter ActiveAdmin, with normal users limited to Dashboard, Jobs, and Tags.
Privileged OAuth credentials and Sidekiq operations must remain unavailable to
normal users at both menu and direct URL boundaries.

## Scope

- Route authenticated normal and admin users to `/admin` after sign-in.
- Show Dashboard, Jobs, and Tags to normal users.
- Allow normal users to use the existing Jobs and Tags actions.
- Show Proposals only to application administrators.
- Show OAuth Credentials only to the designated `admin@example.com` account.
- Restrict direct Proposals and OAuth Credentials access on the server.
- Allow every authenticated application user to access both Sidekiq URL variants.
- Hide the Sidekiq dashboard panel from normal users.
- Keep signup disabled for all account types.

## Acceptance criteria

1. Given an unauthenticated visitor, when `/` is requested, then the visitor passes through `/admin` to `/users/sign_in`.
2. Given a normal user signs in, when the redirect chain completes, then ActiveAdmin renders successfully with Dashboard, Jobs, and Tags links.
3. Given a normal user views ActiveAdmin, then Proposals and OAuth Credentials links are absent and the Sidekiq link is available.
4. Given a normal user, when Proposals or OAuth Credentials is requested directly, then access is denied; when `/sidekiq` or `/sidekiq/` is requested, access succeeds.
5. Given `admin@example.com` signs in, when ActiveAdmin renders, then Proposals, OAuth Credentials, and Sidekiq links are available and their routes are accessible.

## Contracts and constraints

- Existing Devise session URLs and credentials remain compatible.
- ActiveAdmin authenticates against the application `User` session.
- OAuth credential authorization remains email-specific as previously required.
- Proposals authorization uses the application admin role and is enforced by its ActiveAdmin controller.
- Sidekiq authorization requires an authenticated application user and is enforced by Rails routing without a direct Rack mount.
- No database, seed, dependency, tenant, or stateful infrastructure changes are required.
- Rollout rebuilds the application image and restarts `app` and `sidekiq`.
- Rollback restores the previous route, authentication hook, and image.

## Test matrix

| Criterion | Test level | Test case |
| --- | --- | --- |
| AC1 | Integration | Anonymous root follows admin entry to user sign-in |
| AC2 | Integration | Normal login renders ActiveAdmin and its three allowed links |
| AC3 | Integration | Normal menu omits OAuth Credentials and Sidekiq |
| AC4 | Integration | Normal direct privileged requests are denied |
| AC5 | Integration | Designated admin sees and reaches privileged tools |

## Completion evidence

- Red: Pending implementation.
- Green: Pending implementation.
- Broader validation: Pending implementation.
- Skipped checks and remaining risks: Pending implementation.
