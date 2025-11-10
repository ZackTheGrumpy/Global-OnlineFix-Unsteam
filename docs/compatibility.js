// Compatibility data structure
// This will be replaced with actual data from JSON/XML file
let compatibilityData = [];

// Sample data structure (for reference when populating real data)
const sampleData = [
    {
        name: "Paint the Town Red",
        appId: "337320",
        status: "works",
        notes: "LAN play confirmed",
        lastTested: "2025-11-10"
    }
    // Add more games here
];

// Initialize page
document.addEventListener('DOMContentLoaded', () => {
    // Load compatibility data
    loadCompatibilityData();

    // Setup search
    setupSearch();

    // Setup filters
    setupFilters();

    // Add scroll animation to navbar
    setupNavbar();
});

// Load compatibility data from JSON file
async function loadCompatibilityData() {
    try {
        // Try to load from compatibility-data.json
        const response = await fetch('compatibility-data.json');
        if (response.ok) {
            compatibilityData = await response.json();
            populateTable(compatibilityData);
            updateStats(compatibilityData);
        } else {
            // If no data file exists, show placeholder
            console.log('No compatibility data available yet');
        }
    } catch (error) {
        console.log('Compatibility data will be added in the future');
    }
}

// Populate table with compatibility data
function populateTable(data) {
    const tbody = document.getElementById('compatTableBody');

    if (!data || data.length === 0) {
        // Keep the "Coming Soon" message
        return;
    }

    // Clear existing rows
    tbody.innerHTML = '';

    data.forEach((game, index) => {
        const row = document.createElement('tr');
        row.style.animationDelay = `${index * 0.05}s`;

        row.innerHTML = `
            <td><strong>${game.name}</strong></td>
            <td>${game.appId || 'N/A'}</td>
            <td>${getStatusBadge(game.status)}</td>
            <td>${game.notes || '—'}</td>
            <td>${game.lastTested || 'Unknown'}</td>
        `;

        tbody.appendChild(row);
    });
}

// Get status badge HTML
function getStatusBadge(statusValue) {
    if (!statusValue) return '<span class="status-badge status-untested">?</span>';

    const statusMap = {
        'works': { icon: '✓', class: 'status-works' },
        'fails': { icon: '✗', class: 'status-fails' },
        'untested': { icon: '?', class: 'status-untested' }
    };

    const status = statusMap[statusValue] || statusMap['untested'];
    return `<span class="status-badge ${status.class}">${status.icon}</span>`;
}

// Update statistics
function updateStats(data) {
    if (!data || data.length === 0) return;

    const totalGames = data.length;
    let workingGames = 0;
    let failingGames = 0;

    data.forEach(game => {
        if (game.status === 'works') {
            workingGames++;
        } else if (game.status === 'fails') {
            failingGames++;
        }
    });

    document.getElementById('totalGames').textContent = totalGames;
    document.getElementById('workingGames').textContent = workingGames;
    document.getElementById('failingGames').textContent = failingGames;
}

// Setup search functionality
function setupSearch() {
    const searchInput = document.getElementById('searchInput');

    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.toLowerCase();
        filterTable(searchTerm);
    });
}

// Filter table based on search term and active filter
function filterTable(searchTerm = '') {
    const tbody = document.getElementById('compatTableBody');
    const rows = tbody.querySelectorAll('tr');
    const activeFilter = document.querySelector('.filter-btn.active')?.dataset.filter || 'all';

    rows.forEach(row => {
        const cells = row.querySelectorAll('td');
        if (cells.length === 1) return; // Skip "no data" row

        const gameName = cells[0]?.textContent.toLowerCase() || '';
        const appId = cells[1]?.textContent.toLowerCase() || '';

        const matchesSearch = gameName.includes(searchTerm) || appId.includes(searchTerm);

        let matchesFilter = true;
        if (activeFilter !== 'all') {
            const statusBadge = cells[2]?.querySelector('.status-badge'); // Status is now in column 2

            if (activeFilter === 'works') {
                matchesFilter = statusBadge?.classList.contains('status-works');
            } else if (activeFilter === 'fails') {
                matchesFilter = statusBadge?.classList.contains('status-fails');
            }
        }

        row.style.display = (matchesSearch && matchesFilter) ? '' : 'none';
    });
}

// Setup filter buttons
function setupFilters() {
    const filterButtons = document.querySelectorAll('.filter-btn');

    filterButtons.forEach(button => {
        button.addEventListener('click', () => {
            // Remove active class from all buttons
            filterButtons.forEach(btn => btn.classList.remove('active'));

            // Add active class to clicked button
            button.classList.add('active');

            // Apply filter
            const searchInput = document.getElementById('searchInput');
            filterTable(searchInput.value.toLowerCase());
        });
    });
}

// Setup navbar scroll effect
function setupNavbar() {
    const navbar = document.querySelector('.navbar');

    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }
    });
}

// Export data as CSV (utility function for future use)
function exportToCSV() {
    if (!compatibilityData || compatibilityData.length === 0) {
        alert('No data to export');
        return;
    }

    const headers = ['Game Name', 'App ID', 'Status', 'Notes', 'Last Tested'];
    const rows = compatibilityData.map(game => [
        game.name,
        game.appId || 'N/A',
        game.status || 'untested',
        game.notes || '',
        game.lastTested || 'Unknown'
    ]);

    const csv = [headers, ...rows]
        .map(row => row.map(cell => `"${cell}"`).join(','))
        .join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'unsteam-compatibility-list.csv';
    a.click();
    URL.revokeObjectURL(url);
}

// Function to load data from XML (for future use)
async function loadFromXML(xmlUrl) {
    try {
        const response = await fetch(xmlUrl);
        const xmlText = await response.text();
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(xmlText, 'text/xml');

        const games = xmlDoc.querySelectorAll('game');
        const data = [];

        games.forEach(game => {
            data.push({
                name: game.querySelector('name')?.textContent || '',
                appId: game.querySelector('appId')?.textContent || '',
                status: game.querySelector('status')?.textContent || 'untested',
                notes: game.querySelector('notes')?.textContent || '',
                lastTested: game.querySelector('lastTested')?.textContent || ''
            });
        });

        compatibilityData = data;
        populateTable(compatibilityData);
        updateStats(compatibilityData);
    } catch (error) {
        console.error('Error loading XML data:', error);
    }
}

// Console info
console.log('%c📊 Unsteam Compatibility Database', 'font-size: 16px; font-weight: bold; color: #667eea;');
console.log('To populate with data, create a compatibility-data.json file in the same directory.');
console.log('Or use loadFromXML("your-file.xml") to load from XML.');
