# UX QA Checklist

## Guest
- Splash redirects to `/home` without visible errors.
- Guest can open `Hotels`, apply filters, and open hotel detail.
- Hotel detail supports date selection and shows offerings.
- Cart opens, and `Continue` leads to `Your Details`.

## Customer
- Login redirects correctly to `/home`.
- Profile screen loads name, email, role, and data controls.
- Booking flow completes: details -> review -> payment -> confirmation.
- `My Bookings` search by booking ID returns latest result.

## Staff
- Login redirects to `/staff/home`.
- Staff home exposes booking lookup and profile actions.
- Staff without association is redirected to `/staff/request-association`.

## Hotel Admin
- Dashboard actions (`Hotel`, `Rooms`, `Offerings`, `Bookings`, `Payments`) open valid routes.
- Active hotel selection persists between actions.
- Add/Edit hotel form validates correctly (required and optional fields).
- Room/Offering management screens navigate without `Page not found`.

## System Admin
- Login redirects to `/system-admin/home`.
- Admin page loads without placeholder errors or routing dead-ends.

## Cross-Cutting
- No route dead-ends from primary CTAs.
- Bottom navigation switches tabs without stacking back stack unexpectedly.
- Currency is consistently shown in `TZS`.
- Privacy Policy URL is consistent across signup/profile/settings.
- Error states display actionable retry messaging.
