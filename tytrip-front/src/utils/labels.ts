import type { ReservationEvent, ReservationStatus } from '@/api/types'

export const reservationStatusLabels: Record<ReservationStatus, string> = {
  pending: 'En attente',
  confirmed: 'Confirmée',
  checked_in: 'Arrivé',
  checked_out: 'Parti',
  cancelled: 'Annulée',
  no_show: 'Non présenté',
}

export const reservationStatusTypes: Record<ReservationStatus, 'warning' | 'success' | 'primary' | 'info' | 'danger'> = {
  pending: 'warning',
  confirmed: 'success',
  checked_in: 'primary',
  checked_out: 'info',
  cancelled: 'danger',
  no_show: 'danger',
}

export const reservationEventLabels: Record<ReservationEvent, string> = {
  confirm: 'Confirmer',
  check_in: 'Enregistrer l’arrivée',
  check_out: 'Enregistrer le départ',
  cancel: 'Annuler',
  mark_no_show: 'Non présenté',
}

export const reservationSources: Record<string, string> = {
  direct: 'Direct',
  phone: 'Téléphone',
  email: 'Email',
  website: 'Site web',
  airbnb: 'Airbnb',
  booking_com: 'Booking.com',
  vrbo: 'Vrbo',
  other: 'Autre',
}

export const propertyTypes: Record<string, string> = {
  apartment: 'Appartement',
  house: 'Maison',
  villa: 'Villa',
  chalet: 'Chalet',
  guesthouse: 'Maison d’hôtes',
  hotel: 'Hôtel',
  room: 'Chambre',
  other: 'Autre',
}

export const amenityLabels: Record<string, string> = {
  wifi: 'Wi-Fi',
  parking: 'Parking',
  pool: 'Piscine',
  air_conditioning: 'Climatisation',
  heating: 'Chauffage',
  kitchen: 'Cuisine',
  washing_machine: 'Lave-linge',
  dishwasher: 'Lave-vaisselle',
  tv: 'Télévision',
  elevator: 'Ascenseur',
  garden: 'Jardin',
  terrace: 'Terrasse',
  balcony: 'Balcon',
  bbq: 'Barbecue',
  pets_allowed: 'Animaux acceptés',
  wheelchair_access: 'Accès PMR',
  baby_cot: 'Lit bébé',
}

export const blockReasons: Record<string, string> = {
  owner: 'Séjour propriétaire',
  maintenance: 'Travaux / maintenance',
  closed: 'Fermeture',
  other: 'Autre',
}

export const permissionGroups: Record<string, string> = {
  organization: 'Organisation',
  members: 'Membres',
  roles: 'Rôles',
  audit: 'Audit',
  properties: 'Propriétés',
  reservations: 'Réservations',
  guests: 'Voyageurs',
  rates: 'Tarifs',
  housekeeping: 'Ménage',
  maintenance: 'Maintenance',
  billing: 'Facturation',
  reports: 'Rapports',
}
