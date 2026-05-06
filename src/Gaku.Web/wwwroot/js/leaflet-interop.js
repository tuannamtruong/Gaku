// Leaflet map instances keyed by element ID
const maps = {};

export function initMap(elementId, lat, lon, zoom) {
    if (maps[elementId]) {
        maps[elementId].remove();
    }

    const map = L.map(elementId).setView([lat, lon], zoom);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        maxZoom: 19
    }).addTo(map);

    maps[elementId] = { map, trailLayers: L.layerGroup().addTo(map) };
}

export function renderTrails(elementId, trails) {
    const instance = maps[elementId];
    if (!instance) return;

    instance.trailLayers.clearLayers();

    for (const trail of trails) {
        if (!trail.path || trail.path.length < 2) continue;

        const latLngs = trail.path.map(p => [p.latitude, p.longitude]);

        const line = L.polyline(latLngs, {
            color: difficultyColor(trail.difficulty),
            weight: 3,
            opacity: 0.8
        });

        line.bindPopup(`
            <strong>${trail.name}</strong><br/>
            ${trail.surface ? `Surface: ${trail.surface}` : ''}
        `);

        instance.trailLayers.addLayer(line);
    }
}

export function setView(elementId, lat, lon, zoom) {
    const instance = maps[elementId];
    if (instance) instance.map.setView([lat, lon], zoom);
}

export function destroyMap(elementId) {
    const instance = maps[elementId];
    if (instance) {
        instance.map.remove();
        delete maps[elementId];
    }
}

function difficultyColor(difficulty) {
    switch (difficulty?.toLowerCase()) {
        case 'easy':        return '#22c55e';
        case 'moderate':    return '#f59e0b';
        case 'hard':        return '#ef4444';
        case 'expert':      return '#7c3aed';
        default:            return '#3b82f6';
    }
}
