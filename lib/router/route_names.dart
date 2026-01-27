class RouteNames {
  static const splash = '/';
  static const guestHome = '/home'; // explore
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const hotelDetail = '/hotel/:hotelId';
  static const hotels = '/hotels';

  // Staff
  static const staffHome = '/staff/home';
  static const requestHotelAssociation = '/staff/request-association';

  // Hotel Admin
  static const hotelAdminHome = '/hotel-admin/home';
  static const managerHotel = '/manager-hotel/:hotelId';
  static const offerings = '/offerings/:hotelId';
  static const rooms = '/rooms/:hotelId';
  static const hotelBookings = '/bookings/:hotelId';
  static const editHotel = '/edit-hotel/:hotelId';
  static const editRoom = '/edit-room/:roomId/:hotelId';
  static const editOffering = '/edit-offering/:offeringId/:hotelId';

  // System Admin
  static const systemAdminHome = '/system-admin/home';

  // Auth layout
  static const authLayout = '/auth';

  static const bookings = '/bookings'; // bookings screen for customers and staff
  static const profile = '/profile'; // profile screen for customers, staff, hotel admin,

    // Booking flow
  static const bookingInitiate = '/booking/initiate';
  static const bookingReview = '/booking-review';              // + /:bookingId
  static const payment = '/payment';                           // + /:bookingId
  static const bookingConfirmation = '/booking-confirmation';

  static const hotelList = '/hotel-list';

  static const addHotel = '/add-hotel';

  static const addOfferings = '/add-offering/:hotelId';
  static const addRooms = '/add-room/:hotelId';

  static const roomBookings = '/room-bookings/:roomId';

  static const roomDetails = '/room-details/:roomId';

  static const managerPayments = '/manager-payments/:hotelId';

  static const deleteAccount = '/delete-account/:isManager';

  static const settings = '/settings';

}