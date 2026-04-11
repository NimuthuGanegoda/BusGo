export interface Bus {
  id: string;
  registration: string;
  route: number;
  driver: string;
  passengers: number;
  capacity: number;
  status: 'Active' | 'Breakdown' | 'In Repair' | 'Standby';
  speed?: number;
  lat?: number;
  lng?: number;
  nextStop?: string;
  eta?: number;
  lastUpdated?: string;
}

export interface StandbyBus {
  id: string;
  registration: string;
}

export interface Driver {
  id: string;
  name: string;
  rating: number;
  email: string;
  phone: string;
  route: number | null;
  status: 'Active' | 'Inactive' | 'Pending';
  pendingReview?: boolean;
}

export interface EmergencyAlert {
  id: string;
  priority: 'P1' | 'P2' | 'P3';
  type: 'MEDICAL' | 'ACCIDENT' | 'CRIMINAL' | 'BREAKDOWN';
  title: string;
  busId: string;
  driver: string;
  location: string;
  route: number;
  time: string;
  timeAgo: string;
  status: 'NEW' | 'RESPONDED' | 'RESOLVED';
  gps?: { lat: number; lng: number };
  policeNotified?: boolean;
}

export interface Passenger {
  id: string;
  name: string;
  email: string;
  phone: string;
  nic: string;
  status: 'Active' | 'Suspended' | 'Inactive';
  tripsToday: number;
  totalTrips: number;
  registeredDate: string;
}

export interface Admin {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: 'Super Admin' | 'Admin' | 'Moderator';
  status: 'Active' | 'Inactive';
  lastLogin: string;
}

export interface Notification {
  id: string;
  type: 'emergency' | 'system' | 'driver' | 'passenger';
  title: string;
  message: string;
  time: string;
  read: boolean;
}

export interface AuditLog {
  id: string;
  timestamp: string;
  admin: string;
  action: 'RESOLVE' | 'UPDATE' | 'CREATE' | 'DELETE' | 'LOGIN';
  entity: string;
  entityId: string;
  details: string;
  ipAddress: string;
}
