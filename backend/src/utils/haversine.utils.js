/**
 * Calculate the great-circle distance between two GPS coordinates
 * using the Haversine formula.
 *
 * @param {number} lat1 - Latitude of point 1 (degrees)
 * @param {number} lng1 - Longitude of point 1 (degrees)
 * @param {number} lat2 - Latitude of point 2 (degrees)
 * @param {number} lng2 - Longitude of point 2 (degrees)
 * @returns {number} Distance in kilometres
 */
export function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth radius in km
  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;

  return R * 2 * Math.asin(Math.sqrt(a));
}

/**
 * Filter an array of objects with lat/lng fields to those within a given radius.
 *
 * @template T
 * @param {T[]} items           - Array of items with latitude & longitude fields
 * @param {number} centerLat
 * @param {number} centerLng
 * @param {number} radiusKm
 * @param {string} latField     - Field name for latitude  (default: 'latitude')
 * @param {string} lngField     - Field name for longitude (default: 'longitude')
 * @returns {Array<T & { distance_km: number }>}
 */
export function filterByRadius(items, centerLat, centerLng, radiusKm, latField = 'latitude', lngField = 'longitude') {
  return items
    .map((item) => ({
      ...item,
      distance_km: haversineKm(centerLat, centerLng, item[latField], item[lngField]),
    }))
    .filter((item) => item.distance_km <= radiusKm)
    .sort((a, b) => a.distance_km - b.distance_km);
}
