# Soko Mtandao UAT Test Guide

## Purpose
Use this guide to confirm that all key user flows work correctly before release.
Each tester should complete the sections that match their role.

## Tester Details

| Item | Details |
| --- | --- |
| Tester name |  |
| Test date |  |
| Device / browser |  |
| Role tested | Guest / Customer / Staff / Hotel Admin / System Admin |
| Build version |  |

## How To Use This Guide
- Mark each test as `Pass`, `Fail`, or `N/A`.
- Add a short note only if something fails or is unclear.
- If you raise a defect, include the screen name and what happened.

## Entry Criteria
- App is installed or accessible.
- Correct test login details are available.
- Internet connection is stable.

## UAT Scenarios

### 1. Guest User Flow

| ID | Test Scenario | Expected Result | Status | Comments |
| --- | --- | --- | --- | --- |
| G1 | Open the app | App opens without crash and loads the home screen |
| G2 | Open Hotels | Hotel listing screen loads correctly |
| G3 | Search or filter hotels | Results update correctly |
| G4 | Open a hotel detail page | Hotel details, dates, and offerings are displayed |
| G5 | Select dates and start a booking | User can continue to the details step |
| G6 | Move between Home, Hotels, and other visible navigation items | Navigation works without dead ends |

### 2. Customer User Flow

| ID | Test Scenario | Expected Result | Status | Comments |
| --- | --- | --- | --- | --- |
| C1 | Sign up as a new user | Account is created successfully |
| C2 | Log in as an existing user | User is authenticated successfully |
| C3 | Open profile | Profile information loads correctly |
| C4 | Search hotels and open hotel detail | Hotel search and detail flow works correctly |
| C5 | Complete booking details step | User details can be entered and saved |
| C6 | Complete booking review step | Booking summary is accurate |
| C7 | Complete payment step | Payment flow completes successfully |
| C8 | Open booking confirmation | Confirmation page shows the booking result |
| C9 | Search for an existing booking | Booking search returns the correct booking |
| C10 | Move between Home, Hotels, Bookings, and Profile | Navigation works correctly |

### 3. Staff User Flow

| ID | Test Scenario | Expected Result | Status | Comments |
| --- | --- | --- | --- | --- |
| S1 | Log in as staff | User lands on Staff Home |
| S2 | Search for a booking | Booking lookup works correctly |
| S3 | Open profile | Profile screen loads correctly |
| S4 | Log in without hotel association | User is redirected to request association or pending access flow |
| S5 | Submit hotel association request if applicable | Request flow works and user sees the correct next state |

### 4. Hotel Admin Full User Flow

| ID | Test Scenario | Expected Result | Status | Comments |
| --- | --- | --- | --- | --- |
| H1 | Log in as Hotel Admin | User lands on the dashboard |
| H2 | Open dashboard actions | Main admin actions open correctly |
| H3 | Open hotel list or active hotel view | Hotel records load correctly |
| H4 | Add a new hotel | Hotel can be created successfully |
| H5 | Edit hotel details | Changes save successfully and validations work |
| H6 | Open a hotel detail page | Hotel details load correctly |
| H7 | Open Offerings for a hotel | Offerings list loads correctly |
| H8 | Add a new offering | Offering can be created successfully |
| H9 | Edit an offering | Offering changes save successfully |
| H10 | Open Rooms for a hotel | Rooms list loads correctly |
| H11 | Add a new room | Room can be created successfully |
| H12 | Edit a room | Room changes save successfully |
| H13 | Open room details | Room detail page loads correctly |
| H14 | Open room bookings or occupancy calendar | Occupancy data loads correctly |
| H15 | Open Bookings for a hotel | Bookings list loads correctly |
| H16 | Open a booking detail from the list | Booking detail page loads correctly |
| H17 | Open Payments | Payments page loads correctly |
| H18 | Open Team management | Team page loads correctly |
| H19 | Open Notifications | Notifications page loads correctly |
| H20 | Open KYC screen | KYC page loads correctly |
| H21 | Open Settings | Settings page loads correctly |
| H22 | Open manager profile edit | Profile edit page loads and saves correctly |
| H23 | Switch between Dashboard, Hotel, Offerings, Rooms, Bookings, Payments, and Settings | Navigation works without page errors or dead ends |

### 5. System Admin Full User Flow

| ID | Test Scenario | Expected Result | Status | Comments |
| --- | --- | --- | --- | --- |
| A1 | Log in as System Admin | User lands on System Admin dashboard |
| A2 | Open all visible dashboard actions | Each action opens correctly |
| A3 | Review available admin information on the dashboard | Data loads correctly without placeholders or broken sections |
| A4 | Move between visible admin navigation items | Navigation works correctly without route errors |

### 6. Onboarding and Access Flow

| ID | Test Scenario | Expected Result | Status | Comments |
| --- | --- | --- | --- | --- |
| O1 | Open onboarding hub when applicable | User sees the correct onboarding options |
| O2 | Complete manager onboarding flow | Flow opens, validates, and submits correctly |
| O3 | Complete staff onboarding flow | Flow opens, validates, and submits correctly |
| O4 | Open pending access screen when approval is not yet granted | Pending state is shown correctly |

### 7. Cross-Check Items

| ID | Test Scenario | Expected Result | Status | Comments |
| --- | --- | --- | --- | --- |
| X1 | Error handling | Errors show clear and useful messages |
| X2 | Back and forward navigation | Navigation behaves correctly |
| X3 | Currency display | Currency is shown consistently in `TZS` |
| X4 | Privacy policy, terms, and key links | Links open the correct destination |
| X5 | General performance | Main screens load in reasonable time |
| X6 | No visible crashes or blank screens | All tested flows remain stable |

## Defect Log

| Defect ID | Screen / Feature | Steps Taken | Actual Result | Expected Result | Severity |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |

## Sign-Off

| Decision | Name | Date | Notes |
| --- | --- | --- | --- |
| Approved / Not Approved |  |  |  |
