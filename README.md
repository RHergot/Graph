# BI Reporting Module

## 📊 Business Intelligence Reporting Suite

A modern, multilingual BI reporting application built with PySide6/Qt6, featuring interactive data visualization, multi-axis charting, and database connectivity.

### ✨ Features

- **🌍 Multilingual Support**: English (default) with Qt translation system ready for French and other languages
- **📊 Advanced Charting**: Multi-axis charts with independent scales, multiple series support
- **💾 Database Integration**: PostgreSQL connectivity with VIEW discovery and analysis
- **🎨 Modern UI**: Full HD optimized interface with responsive design
- **⚡ Real-time Analysis**: Background processing with progress indicators
- **📈 Multiple Chart Types**: Line, Bar, Pie, Histogram, and Scatter plots

### 🏗️ Architecture

```
app/
├── config/          # Configuration and logging
├── models/          # Database and analysis engine
├── views/           # Qt UI components
├── controllers/     # Business logic controllers
└── utils/           # Utilities and workers

main.py              # Application entry point
```

### 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/bi-reporting-module.git
   cd bi-reporting-module
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure database**
   ```bash
   cp app/config/database.ini.example app/config/database.ini
   # Edit database.ini with your PostgreSQL credentials
   ```

4. **Run the application**
   ```bash
   python main.py
   ```

### 🔧 Configuration

#### Database Configuration
Edit `app/config/database.ini`:
```ini
[DATABASE]
host = localhost
port = 5432
database = your_database
user = your_username
password = your_password
```

#### Translation Support
The application uses Qt's translation system:
- Default language: English
- To add French: Create `translations/app_fr.ts` and compile to `.qm`
- Load translations in `main.py`

### 📊 Data Sources

The application automatically discovers PostgreSQL VIEWs with prefixes:
- `v_*` - Standard views
- `rpt_*` - Report views  
- `kpi_*` - KPI dashboards
- `dash_*` - Dashboard views

### 🎯 Chart Features

- **Multi-axis Support**: Up to 3 Y-axes with independent scales
- **Color-coded Axes**: Left axis (blue), Right axis (orange)
- **Chart Types**: Line, Bar, Pie, Histogram, Scatter
- **Date Filtering**: Automatic date column detection and filtering
- **Export Capabilities**: Chart and data export functionality

### 🔍 Requirements

- **Python**: 3.8+
- **Qt**: 6.4+
- **Database**: PostgreSQL 12+
- **OS**: Windows, Linux, macOS

### 🚀 Server Deployment

For server deployment, consider:

1. **Docker Container**
   ```dockerfile
   FROM python:3.11-slim
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY . /app
   WORKDIR /app
   CMD ["python", "main.py"]
   ```

2. **Virtual Display** (for headless servers)
   ```bash
   sudo apt-get install xvfb
   xvfb-run -a python main.py
   ```

### 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

### 🐛 Known Issues

- Charts require data selection for proper rendering
- Date filtering assumes standard date formats
- Large datasets (>10k rows) may impact performance

### 🎯 Roadmap

- [ ] Real-time data refresh
- [ ] Advanced filtering options
- [ ] Custom SQL query builder
- [ ] Dashboard creation wizard
- [ ] REST API for remote access
- [ ] Mobile-responsive web interface

---

**Built with ❤️ using PySide6/Qt6**
#   G r a p h  
 