# 🐳 Enhanced Loan Default Prediction API - Docker Image
# Production-ready containerized ML API with optimized performance

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MODEL_PATH=/app/exported_model_tuned \
    PORT=9000

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY enhanced_api.py .
COPY train.py .
COPY hyperparameter_search.py .

# Copy model artifacts
COPY exported_model_tuned/ ./exported_model_tuned/

# Copy sample data (for validation)
COPY loan_default_sample.csv .

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:9000/health')" || exit 1

# Expose port
EXPOSE 9000

# Run the enhanced API
CMD ["python", "enhanced_api.py"]