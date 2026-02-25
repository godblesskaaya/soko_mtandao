from pathlib import Path
import logging

# Define the base path
# base_path = Path("features/hotel_manager/domain/usecases")

# Define the folder structure and files
structure = {
    "hotels": [
        "get_hotels_for_manager.dart",
        "get_hotel_detail.dart",
        "add_hotel.dart",
        "update_hotel.dart",
        "deactivate_hotel.dart",
        "get_hotel_metrics.dart",
    ],
    "offerings": [
        "get_offerings_for_hotel.dart",
        "add_offering.dart",
        "update_offering.dart",
        "delete_offering.dart",
        "update_offering_pricing.dart",
    ],
    "rooms": [
        "get_rooms_for_offering.dart",
        "add_room.dart",
        "update_room.dart",
        "update_room_status.dart",
        "get_room_availability.dart",
    ],
    "bookings": [
        "get_bookings.dart",
        "get_booking_detail.dart",
        "modify_booking.dart",
        "cancel_booking.dart",
        "export_bookings.dart",
    ],
    "staff": [
        "get_staff_for_hotel.dart",
        "invite_staff.dart",
        "update_staff_role.dart",
        "remove_staff.dart",
    ],
}

# Create the folder structure and empty Dart files
for folder, files in structure.items():
    # folder path is the same as where this file is located
    base_path = Path(__file__).parent
    folder_path = base_path / folder
    folder_path.mkdir(parents=True, exist_ok=True)
    for file_name in files:
        file_path = folder_path / file_name
        file_path.touch()

logging.info("Created use case structure under: %s", base_path)
