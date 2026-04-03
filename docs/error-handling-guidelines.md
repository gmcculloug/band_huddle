# Error Handling Guidelines

## Overview

This document defines the error-handling conventions used in the Band Huddle Sinatra application. All new and modified code must follow these patterns for consistency.

## 1. Two Contexts: HTML Routes vs JSON API Routes

The app has two distinct error-handling paths. Choose the correct one based on the route.

**HTML routes** (browser-facing, in `lib/routes/`): Render ERB templates with `@errors` set.

**JSON API routes** (in `lib/routes/api.rb`, `lib/routes/mobile_api.rb`, and mixed-purpose routes such as those in `lib/routes/gigs.rb`, `lib/routes/songs.rb`, and `lib/routes/oauth.rb`): Return JSON with `content_type :json` and appropriate HTTP status codes.

Prefer not to mix these. An HTML route should not return JSON error bodies, and a JSON route should not redirect or render ERB on error.

## 2. ErrorHandler Service Usage

`ErrorHandler` lives at `lib/services/error_handler.rb`. Use it wherever possible instead of manually setting error variables.

### 2.1 HTML Form Validation Errors

Use `ErrorHandler.setup_form_errors(model, self)` after a failed save/update in HTML routes. This sets `@errors` to `model.errors.full_messages` on the Sinatra route context.

```ruby
if model.save
  redirect "/models/#{model.id}"
else
  ErrorHandler.setup_form_errors(model, self)
  erb :edit_model
end
```

Prefer the service over manually assigning `@errors = model.errors.full_messages` in new code. Many existing routes still use direct assignment (e.g., `put '/gigs/:id'`, `post '/gigs/:id/songs'`, `post '/song_catalog'`, `post '/song_catalogs'`, and routes in `lib/routes/authentication.rb`). All new code should use the service instead.

### 2.2 JSON Validation Errors

Use `ErrorHandler.handle_json_errors(model)` when you need the full structured response with `details`. This returns `false` when no errors exist. Note that existing route files construct validation error JSON directly rather than calling this method; `handle_json_errors` is available for new code.

The actual return shape of `handle_json_errors` is:

```ruby
{ success: false, errors: model.errors.full_messages, details: model.errors.messages }
```

When writing new JSON routes, prefer constructing the wire-format response (see Section 3.1) directly, or use this method with awareness that its shape differs from the `{ "error": ..., "details": ... }` shape produced by existing routes.

```ruby
error_response = ErrorHandler.handle_json_errors(model)
if error_response
  status 422
  return error_response.to_json
end
```

### 2.3 Success Responses

Use `ErrorHandler.success_response` for JSON success payloads:

```ruby
ErrorHandler.success_response(message: "Created!", data: model, redirect_to: "/path")
# => { success: true, message: "Created!", data: model, redirect_to: "/path" }
```

### 2.4 Exception Handling with Logging

Use `ErrorHandler.log_and_respond` in rescue blocks when you want to log the real error and return a safe user-facing message:

```ruby
rescue => e
  message = ErrorHandler.log_and_respond(e, context: "Creating gig", user_message: "Failed to create gig")
```

### 2.5 Checking for Errors Safely

Use `ErrorHandler.has_errors?(model)` when the object may not respond to `.errors`.

### 2.6 Normalizing Error Formats

Use `ErrorHandler.format_errors(input)` when the error source may be an `ActiveModel::Errors`, an `Array`, a `String`, or `nil`.

## 3. JSON API Error Response Shapes

### 3.1 Validation Failure (422)

```json
{ "error": "Validation failed", "details": ["Title can't be blank"] }
```

### 3.2 Not Found (404)

```json
{ "error": "Gig not found" }
```

### 3.3 Bad Request (400)

```json
{ "error": "Invalid date format" }
```

Or for missing prerequisites:

```json
{ "error": "No band selected" }
```

### 3.4 Authentication Failure (401)

```json
{ "success": false, "error": "Invalid username or password" }
```

Or via `require_api_auth` halt:

```json
{ "error": "Authentication required", "code": "UNAUTHORIZED" }
```

### 3.5 Server Error (500)

```json
{ "error": "Failed to fetch gigs" }
```

Use a human-readable, static message. Avoid exposing `exception.message` to API clients in 500 responses. Note that `get '/api/lookup_song'` in `lib/routes/api.rb` is a known exception where `e.message` is included in the response for debugging purposes.

### 3.6 Success Responses

Mutation endpoints (POST/PUT/DELETE) include `success: true`:

```json
{ "success": true, "data": { "id": 1, "name": "..." } }
```

Read endpoints (GET) use a `data`/`meta` envelope without `success`:

```json
{ "data": [...], "meta": { "total_count": 10, "page": 1 } }
```

## 4. Rescue Patterns in JSON API Routes

JSON API actions should be wrapped in a `begin/rescue` block following this ordering convention:

```ruby
begin
  # ... action logic ...
rescue ActiveRecord::RecordNotFound
  status 404
  { error: 'Resource not found' }.to_json
rescue Date::Error
  status 400
  { error: 'Invalid date format' }.to_json
rescue ArgumentError
  status 400
  { error: 'Invalid parameter format' }.to_json
rescue JSON::ParserError
  status 400
  { error: 'Invalid JSON in request' }.to_json
rescue => e
  status 500
  { error: 'Failed to perform action' }.to_json
end
```

Rules:
- Rescue specific exceptions before the generic `rescue => e`.
- The generic 500 rescue must use a static, context-specific message (e.g., "Failed to fetch gigs", "Failed to update song").
- Avoid exposing `e.message` in 500 responses to API clients.
- Always set `status` before returning the JSON body.

## 5. Rescue Patterns in HTML Routes

HTML routes generally do NOT wrap actions in begin/rescue. Exceptions propagate to Sinatra's default error handling unless there is a specific recovery path.

Known exceptions where HTML routes use rescue:

- `post '/account/delete'` in `lib/routes/authentication.rb`: uses `rescue => e` to restore the session and show a user-friendly error if account deletion fails.
- `post '/gigs/:id/copy'` in `lib/routes/gigs.rb`: uses rescue to redirect back with an error query parameter when the copy fails, while re-raising `ActiveRecord::RecordNotFound` to maintain security behavior.

Follow these patterns only for destructive or complex operations with specific recovery needs.

For `ActiveRecord::RecordNotFound` in HTML routes, let it propagate. The `find_user_gig` helper and `filter_by_current_band(Model).find(id)` pattern naturally raise this. The gig copy route explicitly re-raises it:

```ruby
rescue ActiveRecord::RecordNotFound
  raise  # re-raise to maintain security behavior (returns 404/error page)
rescue => e
  redirect "/gigs/#{params[:id]}?error=copy_failed"
end
```

## 6. Authentication Error Handling

### 6.1 HTML Routes

Use `require_login` which redirects to `/login` if not authenticated. No error JSON is returned.

### 6.2 JSON API Routes

Most JSON API routes (including the mobile API routes at `/api/mobile/*`) use `require_login`, which redirects unauthenticated requests to `/login`. Use `require_api_auth` only for endpoints that must return a machine-readable 401 JSON response rather than a redirect — currently this is limited to `GET /api/mobile/auth/validate`. `require_api_auth` calls `halt` with a 401 status and JSON body, immediately stopping request processing.

### 6.3 JWT Authentication Errors

In the `user_from_jwt_token` helper, JWT errors are silently caught and `nil` is returned. Debug logging only occurs in development mode:

```ruby
rescue => e
  puts "JWT authentication error: #{e.message}" if settings.development?
  nil
end
```

### 6.4 Session Recovery

In `user_from_session`, an `ActiveRecord::RecordNotFound` clears the invalid `session[:user_id]` and returns `nil` rather than crashing.

## 7. HTML Error Display

The `views/_errors.erb` partial renders `@errors` as a `<ul>` inside a `div.errors` with `role="alert"`. Include this partial in any form template that may display validation errors.

`@errors` must always be an `Array<String>` of full error messages.

Some routes use `@error` (singular string) for inline error display (e.g., login page, venue copy, and practice scheduling routes). Use `@errors` (plural array) for model validation; use `@error` (singular string) for simple contextual messages only in views that check for it explicitly.

## 8. Band Management Error Pattern

Band user management routes (add/remove/change role) use `@user_error` and `@user_success` instance variables instead of `@errors`. This is specific to the `edit_band` view which separates band-level errors from user-management errors. Follow this pattern when adding band membership features.

## 9. Logging Conventions

- Use `puts "[ERROR] context: message"` format via `ErrorHandler.log_and_respond`.
- Backtrace logging is limited to the first 5 lines.
- In development, JWT errors log via `puts` guarded by `settings.development?`.
- Do not use a logging framework — the app uses `puts` to stdout.

## 10. Precondition Checks

Before performing mutations, validate preconditions with early returns:

```ruby
# JSON route
unless current_band
  status 400
  return { error: 'No band selected' }.to_json
end

# HTML route
return redirect '/gigs' unless current_band
```

Always use `return` with the error response in JSON routes to prevent further execution.

## 11. Status Code Reference

| Situation | Status | Context |
|---|---|---|
| Missing required params | 400 | JSON API |
| No band selected | 400 | JSON API |
| Invalid date/timestamp | 400 | JSON API |
| Invalid credentials | 401 | JSON API |
| Not authenticated | 401 | JSON API (via `require_api_auth`) |
| Access denied | 403 | JSON API |
| Record not found | 404 | JSON API |
| Validation failure | 422 | JSON API |
| Unexpected server error | 500 | JSON API |
