import { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, AttributionControl, useMap } from 'react-leaflet';
import L from 'leaflet';

const destinationIcon = new L.Icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

const riderIcon = new L.DivIcon({
  html: '<div style="background:#2196F3;width:28px;height:28px;border-radius:50%;border:3px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;font-size:14px;">🏍️</div>',
  className: '',
  iconSize: [28, 28],
  iconAnchor: [14, 14],
});

function FitBoundsOnRider({ destination, rider }) {
  const map = useMap();
  useEffect(() => {
    if (rider) {
      map.fitBounds([destination, rider], { padding: [40, 40] });
    }
  }, [map, destination, rider]);
  return null;
}

export default function DeliveryLocationMap({ latitude, longitude, orderId, riderLatitude, riderLongitude }) {
  const [routePoints, setRoutePoints] = useState([]);
  const [routeInfo, setRouteInfo] = useState(null);

  const hasRider = riderLatitude != null && riderLongitude != null;

  useEffect(() => {
    if (!hasRider) {
      setRoutePoints([]);
      setRouteInfo(null);
      return;
    }

    let cancelled = false;
    const fetchRoute = async () => {
      try {
        const url = `https://router.project-osrm.org/route/v1/driving/${riderLongitude},${riderLatitude};${longitude},${latitude}?overview=full&geometries=geojson`;
        const response = await fetch(url);
        const data = await response.json();
        if (cancelled) return;
        if (data.code === 'Ok' && data.routes?.length > 0) {
          const route = data.routes[0];
          const points = route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);
          setRoutePoints(points);
          setRouteInfo({
            distanceKm: (route.distance / 1000).toFixed(1),
            durationMin: Math.round(route.duration / 60),
          });
        }
      } catch (err) {
        // Best-effort — the map still shows both pins without a route line.
      }
    };
    fetchRoute();
    return () => { cancelled = true; };
  }, [hasRider, riderLatitude, riderLongitude, latitude, longitude]);

  return (
    <div style={{ height: '180px', borderRadius: '8px', overflow: 'hidden', marginBottom: '6px', position: 'relative' }}>
      <MapContainer
        center={[latitude, longitude]}
        zoom={16}
        style={{ height: '100%', width: '100%' }}
        scrollWheelZoom={false}
        attributionControl={false}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.maptiler.com/copyright/">MapTiler</a>'
          url={`https://api.maptiler.com/maps/bright-v2/{z}/{x}/{y}.png?key=${
            import.meta.env.VITE_MAPTILER_API_KEY
          }`}
        />
        <AttributionControl prefix={false} />
        {routePoints.length > 0 && (
          <Polyline positions={routePoints} pathOptions={{ color: '#E8865A', weight: 4 }} />
        )}
        <Marker position={[latitude, longitude]} icon={destinationIcon}>
          <Popup>Delivery location for Order #{orderId}</Popup>
        </Marker>
        {hasRider && (
          <Marker position={[riderLatitude, riderLongitude]} icon={riderIcon}>
            <Popup>Rider's current location</Popup>
          </Marker>
        )}
        {hasRider && (
          <FitBoundsOnRider destination={[latitude, longitude]} rider={[riderLatitude, riderLongitude]} />
        )}
      </MapContainer>
      {routeInfo && (
        <div style={styles.routeBadge}>
          🏍️ {routeInfo.distanceKm} km · ~{routeInfo.durationMin} min away
        </div>
      )}
    </div>
  );
}

const styles = {
  routeBadge: {
    position: 'absolute',
    top: '8px',
    left: '8px',
    backgroundColor: '#fff',
    padding: '4px 10px',
    borderRadius: '20px',
    fontSize: '11px',
    fontWeight: 600,
    boxShadow: '0 1px 4px rgba(0,0,0,0.2)',
    zIndex: 1000,
  },
};