document.addEventListener('DOMContentLoaded', () => {
    
    // --- 1. පොදු Sidebar පාලනය (Common Sidebar Logic) ---
    const sidebar = document.querySelector(".sidebar");
    const sidebarBtn = document.querySelector(".sidebarBtn");
    if (sidebarBtn) {
        sidebarBtn.onclick = () => sidebar.classList.toggle("active");
    }

    // --- 2. Logout Logic (අලුතින් එක් කරන ලදී) ---
    const logoutBtn = document.querySelector(".log_out a");
    if (logoutBtn) {
        logoutBtn.addEventListener("click", (e) => {
            e.preventDefault(); // Default link එක වැඩ කිරීම නවත්වයි
            if (confirm("Are you sure you want to log out?")) {
                // මෙතැනදී ඔබට අවශ්‍ය නම් localStorage.clear(); පාවිච්චි කර දත්ත මැකීමට හැක
                // නමුත් සාමාන්‍යයෙන් කරන්නේ login පිටුවට යොමු කිරීමයි
                window.location.href = "login.html"; // ඔබේ login පිටුවේ නම මෙතැනට ඇතුළත් කරන්න
            }
        });
    }

    // Local Storage එකෙන් දත්ත ලබා ගැනීම
    const getDrivers = () => JSON.parse(localStorage.getItem('safeRide_drivers_list')) || [];

    // --- 3. DASHBOARD පිටුවට අදාළ කොටස (index.html) ---
    const monthFilter = document.getElementById('monthFilter');
    const yearFilter = document.getElementById('yearFilter');
    let registrationChart = null;

    if (monthFilter && yearFilter) {
        setupFilters();
        updateDashboardUI();
        monthFilter.addEventListener('change', updateDashboardUI);
        yearFilter.addEventListener('change', updateDashboardUI);
    }

    function setupFilters() {
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        months.forEach((m, i) => {
            let opt = document.createElement('option');
            opt.value = i; opt.innerHTML = m;
            if (i === new Date().getMonth()) opt.selected = true;
            monthFilter.appendChild(opt);
        });

        let currentY = new Date().getFullYear();
        for (let y = currentY - 2; y <= currentY + 2; y++) {
            let opt = document.createElement('option');
            opt.value = y; opt.innerHTML = y;
            if (y === currentY) opt.selected = true;
            yearFilter.appendChild(opt);
        }
    }

    function updateDashboardUI() {
        if (!monthFilter) return;

        const drivers = getDrivers();
        const selMonth = parseInt(monthFilter.value);
        const selYear = parseInt(yearFilter.value);
        
        let monthlyTotal = 0;
        let annualTotal = 0;
        let chartData = new Array(12).fill(0);

        drivers.forEach(d => {
            const dDate = new Date(d.registeredDate);
            const dYear = dDate.getFullYear();
            const dMonth = dDate.getMonth();

            if (dYear === selYear) {
                annualTotal++;
                chartData[dMonth]++;
                if (dMonth === selMonth) {
                    monthlyTotal++;
                }
            }
        });

        document.getElementById('totalDriversCount').innerText = drivers.length;
        document.getElementById('monthlyCount').innerText = monthlyTotal;
        document.getElementById('annualCount').innerText = annualTotal;

        const dashTable = document.getElementById('dashboardTableBody');
        if (dashTable) {
            dashTable.innerHTML = drivers.slice(-5).reverse().map(d => `
                <tr>
                    <td>${d.name}</td>
                    <td>${d.vehicle}</td>
                    <td><span class="status-btn verified">Verified</span></td>
                    <td><button onclick="viewDriver(${d.id})" class="view-btn-modern" style="padding: 5px 15px; background: #083c5a; color: white; border: none; border-radius: 5px; cursor: pointer;">View</button></td>
                </tr>
            `).join('');
        }

        updateChart(chartData, selYear);
    }

    window.viewDriver = (id) => {
        window.location.href = `driver-details.html?id=${id}`;
    };

    function updateChart(data, year) {
        const ctx = document.getElementById('registrationChart');
        if (!ctx) return;
        if (registrationChart) registrationChart.destroy();

        registrationChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
                datasets: [{
                    label: 'Registrations in ' + year,
                    data: data,
                    borderColor: '#083c5a',
                    backgroundColor: 'rgba(8, 60, 90, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: { responsive: true, maintainAspectRatio: false }
        });
    }

    // --- 4. DRIVERS පිටුවට අදාළ කොටස (drivers.html) ---
    const regForm = document.getElementById('driverRegisterForm');
    const driverTable = document.getElementById('driverListTable');

    if (regForm) {
        regForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const drivers = getDrivers();
            const newDriver = {
                id: Date.now(),
                name: document.getElementById('driverName').value,
                vehicle: document.getElementById('vehicleNumber').value,
                phone: document.getElementById('contactNumber').value,
                registeredDate: new Date().toISOString()
            };
            drivers.push(newDriver);
            localStorage.setItem('safeRide_drivers_list', JSON.stringify(drivers));
            alert("Driver Registered Successfully!");
            regForm.reset();
            loadDriversTable();
        });
    }

    function loadDriversTable() {
        if (!driverTable) return;
        const drivers = getDrivers();
        driverTable.innerHTML = drivers.map(d => `
            <tr>
                <td>#${d.id}</td>
                <td>${d.name}</td>
                <td>${d.vehicle}</td>
                <td>${d.phone}</td>
                <td><button onclick="deleteDriver(${d.id})" style="background:red; color:white; border:none; padding:5px 10px; border-radius:5px; cursor:pointer;">Delete</button></td>
            </tr>
        `).join('');
    }

    window.deleteDriver = (id) => {
        if (confirm("Are you sure you want to delete this driver?")) {
            const filtered = getDrivers().filter(d => d.id !== id);
            localStorage.setItem('safeRide_drivers_list', JSON.stringify(filtered));
            loadDriversTable();
        }
    };

    loadDriversTable();
});