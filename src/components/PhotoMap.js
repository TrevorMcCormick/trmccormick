import React, { useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Fix for default marker icon in webpack
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const PhotoMap = ({ locations }) => {
  const [selectedPhoto, setSelectedPhoto] = useState(null);

  // Default to center of world if no locations
  const defaultCenter = [20, 0];
  const defaultZoom = 2;

  // Calculate center based on locations
  const mapCenter = locations.length > 0
    ? [
        locations.reduce((sum, loc) => sum + loc.latitude, 0) / locations.length,
        locations.reduce((sum, loc) => sum + loc.longitude, 0) / locations.length,
      ]
    : defaultCenter;

  return (
    <div style={{ position: 'relative', width: '100%', height: '600px', marginTop: '2rem', marginBottom: '2rem' }}>
      <MapContainer
        center={mapCenter}
        zoom={defaultZoom}
        style={{ height: '100%', width: '100%', borderRadius: '8px' }}
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {locations.map((location, index) => (
          <Marker
            key={index}
            position={[location.latitude, location.longitude]}
            eventHandlers={{
              click: () => setSelectedPhoto(location),
            }}
          >
            <Popup>
              <div style={{ textAlign: 'center' }}>
                <img
                  src={location.path}
                  alt={location.name || location.filename}
                  style={{
                    maxWidth: '250px',
                    maxHeight: '250px',
                    width: '100%',
                    height: 'auto',
                    borderRadius: '4px',
                    marginBottom: '8px'
                  }}
                />
                {location.name && (
                  <p style={{ margin: '0 0 4px 0', fontSize: '1rem', fontWeight: '600' }}>
                    {location.name}
                  </p>
                )}
                {location.description && (
                  <p style={{ margin: '0 0 4px 0', fontSize: '0.85rem', color: '#666' }}>
                    {location.description}
                  </p>
                )}
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>

      {/* Modal for larger image view */}
      {selectedPhoto && (
        <div
          onClick={() => setSelectedPhoto(null)}
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
            cursor: 'pointer',
            padding: '20px',
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              maxWidth: '90vw',
              maxHeight: '90vh',
              position: 'relative',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
            }}
          >
            <img
              src={selectedPhoto.path}
              alt={selectedPhoto.name || selectedPhoto.filename}
              style={{
                maxWidth: '100%',
                maxHeight: selectedPhoto.name || selectedPhoto.description ? '80vh' : '90vh',
                width: 'auto',
                height: 'auto',
                borderRadius: '8px',
                boxShadow: '0 4px 20px rgba(0, 0, 0, 0.5)',
              }}
            />
            {(selectedPhoto.name || selectedPhoto.description) && (
              <div
                style={{
                  backgroundColor: 'white',
                  borderRadius: '8px',
                  padding: '16px 24px',
                  marginTop: '16px',
                  textAlign: 'center',
                  boxShadow: '0 4px 20px rgba(0, 0, 0, 0.5)',
                  maxWidth: '100%',
                }}
              >
                {selectedPhoto.name && (
                  <h3 style={{ margin: '0 0 8px 0', fontSize: '1.25rem', fontWeight: '600' }}>
                    {selectedPhoto.name}
                  </h3>
                )}
                {selectedPhoto.description && (
                  <p style={{ margin: 0, fontSize: '1rem', color: '#666' }}>
                    {selectedPhoto.description}
                  </p>
                )}
              </div>
            )}
            <button
              onClick={() => setSelectedPhoto(null)}
              style={{
                position: 'absolute',
                top: '-15px',
                right: '-15px',
                background: 'white',
                border: 'none',
                borderRadius: '50%',
                width: '40px',
                height: '40px',
                fontSize: '24px',
                cursor: 'pointer',
                boxShadow: '0 2px 8px rgba(0, 0, 0, 0.3)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              ×
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default PhotoMap;
