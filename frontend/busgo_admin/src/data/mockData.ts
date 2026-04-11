import type { Bus, StandbyBus, Driver, EmergencyAlert, AuditLog, Passenger, Admin, Notification } from '../types';

export const activeBuses: Bus[] = [
  {
    id: 'BUS-138-A',
    registration: 'WP-CAR-1234',
    route: 138,
    driver: 'Kamal Perera',
    passengers: 32,
    capacity: 50,
    status: 'Active',
    speed: 34,
    lat: 6.8495,
    lng: 79.8715,
    nextStop: 'Nugegoda Stand',
    eta: 4,
    lastUpdated: '14:32',
  },
  {
    id: 'BUS-220-B',
    registration: 'WP-BA-5678',
    route: 220,
    driver: 'Saman Dias',
    passengers: 41,
    capacity: 50,
    status: 'Active',
    speed: 28,
    lat: 6.9271,
    lng: 79.8612,
    nextStop: 'Colombo Fort',
    eta: 7,
    lastUpdated: '14:30',
  },
  {
    id: 'BUS-176-C',
    registration: 'CP-7890-AB',
    route: 176,
    driver: 'Ranjith Silva',
    passengers: 15,
    capacity: 50,
    status: 'Breakdown',
    speed: 0,
    lat: 6.7856,
    lng: 80.0188,
    nextStop: 'Homagama Depot',
    eta: 0,
    lastUpdated: '13:40',
  },
];

export const standbyBuses: StandbyBus[] = [
  { id: 'BUS-SBY-01', registration: 'WP-KH-0011' },
  { id: 'BUS-SBY-02', registration: 'NW-5432-CD' },
  { id: 'BUS-SBY-03', registration: 'SP-GH-7654' },
  { id: 'BUS-SBY-04', registration: 'WP-PQ-2233' },
  { id: 'BUS-SBY-05', registration: 'CP-AB-9988' },
];

export const drivers: Driver[] = [
  { id: 'DRV-001', name: 'Kamal Perera', rating: 8.4, email: 'kamal@email.com', phone: '+94 77 123 4567', route: 138, status: 'Active' },
  { id: 'DRV-002', name: 'Saman Dias', rating: 7.9, email: 'saman@email.com', phone: '+94 71 987 6543', route: 220, status: 'Active' },
  { id: 'DRV-003', name: 'Nimal Silva', rating: 9.1, email: 'nimal@email.com', phone: '+94 76 555 1234', route: 176, status: 'Inactive' },
  { id: 'DRV-004', name: 'Ruwan Fernando', rating: 0, email: 'ruwan@email.com', phone: '+94 70 321 9876', route: null, status: 'Pending', pendingReview: true },
  { id: 'DRV-005', name: 'Amara Wijesinghe', rating: 8.8, email: 'amara@email.com', phone: '+94 75 444 7890', route: 110, status: 'Active' },
];

export const emergencyAlerts: EmergencyAlert[] = [
  {
    id: 'EM-20260318-003',
    priority: 'P1',
    type: 'MEDICAL',
    title: 'Medical Emergency — Passenger',
    busId: 'Bus #138-A',
    driver: 'Kamal Perera',
    location: 'Near Nugegoda Bus Stand',
    route: 138,
    time: '14:28',
    timeAgo: '6 min ago',
    status: 'NEW',
    gps: { lat: 6.8895, lng: 79.8615 },
  },
  {
    id: 'EM-20260318-004',
    priority: 'P1',
    type: 'ACCIDENT',
    title: 'Road Accident Reported',
    busId: 'Bus #155-D',
    driver: 'Priyantha Bandara',
    location: 'Kaduwela Junction',
    route: 155,
    time: '14:15',
    timeAgo: '19 min ago',
    status: 'NEW',
  },
  {
    id: 'EM-20260318-002',
    priority: 'P2',
    type: 'CRIMINAL',
    title: 'Criminal Activity on Board',
    busId: 'Bus #220-B',
    driver: 'Saman Dias',
    location: 'Colombo Fort',
    route: 220,
    time: '13:55',
    timeAgo: '39 min ago',
    status: 'RESPONDED',
    policeNotified: true,
  },
  {
    id: 'EM-20260318-001',
    priority: 'P3',
    type: 'BREAKDOWN',
    title: 'Vehicle Breakdown',
    busId: 'Bus #176-C',
    driver: 'Ranjith Silva',
    location: 'Homagama Depot',
    route: 176,
    time: '13:40',
    timeAgo: '54 min ago',
    status: 'NEW',
  },
  {
    id: 'EM-20260318-000',
    priority: 'P3',
    type: 'BREAKDOWN',
    title: 'Engine Fault',
    busId: 'Bus #103-E',
    driver: 'Asanka Jayasuriya',
    location: 'Pettah',
    route: 103,
    time: '12:10',
    timeAgo: 'Resolved',
    status: 'RESOLVED',
  },
];

export const auditLogs: AuditLog[] = [
  { id: '1', timestamp: '2026-03-18 14:28:03', admin: 'admin@busgo.lk', action: 'RESOLVE', entity: 'EmergencyAlert', entityId: 'EM-20260318-003', details: 'Marked Medical Emergency as resolved. Bus #138-A', ipAddress: '192.168.1.10' },
  { id: '2', timestamp: '2026-03-18 13:55:41', admin: 'admin@busgo.lk', action: 'UPDATE', entity: 'Driver', entityId: 'DRV-002', details: 'Updated route assignment: Route 155 → Route 220', ipAddress: '192.168.1.10' },
  { id: '3', timestamp: '2026-03-18 13:20:14', admin: 'admin@busgo.lk', action: 'CREATE', entity: 'Driver', entityId: 'DRV-047', details: 'Approved and activated new driver: Amara Wijesinghe', ipAddress: '192.168.1.10' },
  { id: '4', timestamp: '2026-03-18 12:10:55', admin: 'admin@busgo.lk', action: 'RESOLVE', entity: 'EmergencyAlert', entityId: 'EM-20260318-002', details: 'Resolved breakdown alert. Standby BUS-SBY-02 deployed', ipAddress: '192.168.1.10' },
  { id: '5', timestamp: '2026-03-18 11:45:22', admin: 'admin@busgo.lk', action: 'DELETE', entity: 'Passenger', entityId: 'PSG-2089', details: 'Deleted suspended passenger account (policy violation)', ipAddress: '192.168.1.10' },
  { id: '6', timestamp: '2026-03-18 09:00:01', admin: 'admin@busgo.lk', action: 'LOGIN', entity: 'AdminSession', entityId: '—', details: 'Successful admin login via credential auth', ipAddress: '192.168.1.10' },
  { id: '7', timestamp: '2026-03-17 16:30:07', admin: 'admin@busgo.lk', action: 'UPDATE', entity: 'Bus', entityId: 'BUS-176-C', details: 'Status changed: Active → In Maintenance', ipAddress: '192.168.1.10' },
];

export const dashboardStats = {
  activeBuses: 24,
  activeBusesChange: '+2 since yesterday',
  passengersToday: 1247,
  passengersChange: '+184 vs avg',
  pendingAlerts: 3,
  alertsNote: 'Needs attention',
  standbyBuses: 5,
  standbyNote: 'Ready to deploy',
};

export const fleetStats = {
  totalFleet: 29,
  active: 24,
  standby: 5,
  inRepair: 1,
};

export const passengers: Passenger[] = [
  { id: 'PSG-001', name: 'Dinesh Kumara', email: 'dinesh@email.com', phone: '+94 77 234 5678', nic: '199812345678', status: 'Active', tripsToday: 2, totalTrips: 142, registeredDate: '2025-06-15' },
  { id: 'PSG-002', name: 'Sachini Fernando', email: 'sachini@email.com', phone: '+94 71 876 5432', nic: '200145678901', status: 'Active', tripsToday: 1, totalTrips: 89, registeredDate: '2025-08-22' },
  { id: 'PSG-003', name: 'Nuwan Jayawardena', email: 'nuwan@email.com', phone: '+94 76 333 4444', nic: '198756789012', status: 'Suspended', tripsToday: 0, totalTrips: 215, registeredDate: '2025-03-10' },
  { id: 'PSG-004', name: 'Chamari Silva', email: 'chamari@email.com', phone: '+94 75 111 2222', nic: '199523456789', status: 'Active', tripsToday: 3, totalTrips: 67, registeredDate: '2025-11-01' },
  { id: 'PSG-005', name: 'Tharanga Perera', email: 'tharanga@email.com', phone: '+94 70 555 6666', nic: '199234567890', status: 'Inactive', tripsToday: 0, totalTrips: 34, registeredDate: '2025-09-18' },
  { id: 'PSG-006', name: 'Lakshika Bandara', email: 'lakshika@email.com', phone: '+94 77 888 9999', nic: '200067890123', status: 'Active', tripsToday: 1, totalTrips: 178, registeredDate: '2025-05-05' },
];

export const admins: Admin[] = [
  { id: 'ADM-001', name: 'Admin Master', email: 'admin@busgo.lk', phone: '+94 77 000 0001', role: 'Super Admin', status: 'Active', lastLogin: '2026-03-18 14:28' },
  { id: 'ADM-002', name: 'Kasun Rajapaksha', email: 'kasun@busgo.lk', phone: '+94 71 000 0002', role: 'Admin', status: 'Active', lastLogin: '2026-03-18 09:15' },
  { id: 'ADM-003', name: 'Dilani Wickramasinghe', email: 'dilani@busgo.lk', phone: '+94 76 000 0003', role: 'Moderator', status: 'Active', lastLogin: '2026-03-17 16:30' },
  { id: 'ADM-004', name: 'Pradeep Gunasekara', email: 'pradeep@busgo.lk', phone: '+94 75 000 0004', role: 'Admin', status: 'Inactive', lastLogin: '2026-02-28 11:00' },
];

export const notifications: Notification[] = [
  { id: 'N-001', type: 'emergency', title: 'Medical Emergency', message: 'Medical emergency reported on Bus #138-A near Nugegoda', time: '2 min ago', read: false },
  { id: 'N-002', type: 'emergency', title: 'Road Accident', message: 'Accident reported on Bus #155-D at Kaduwela Junction', time: '19 min ago', read: false },
  { id: 'N-003', type: 'driver', title: 'New Driver Application', message: 'Ruwan Fernando submitted a new driver application', time: '1 hour ago', read: false },
  { id: 'N-004', type: 'system', title: 'System Update', message: 'AXIS system updated to v3.2.1 successfully', time: '3 hours ago', read: true },
  { id: 'N-005', type: 'passenger', title: 'Passenger Report', message: 'Passenger PSG-003 reported for policy violation', time: '5 hours ago', read: true },
  { id: 'N-006', type: 'emergency', title: 'Criminal Activity', message: 'Criminal activity reported on Bus #220-B at Colombo Fort', time: '39 min ago', read: false },
  { id: 'N-007', type: 'system', title: 'Bus Breakdown', message: 'Bus #176-C engine failure at Homagama Depot', time: '54 min ago', read: true },
  { id: 'N-008', type: 'driver', title: 'Driver Rating Update', message: 'Driver Nimal Silva rating dropped below threshold', time: '2 hours ago', read: true },
];
