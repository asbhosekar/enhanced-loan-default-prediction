# EC2 API Monitor Script
param(
    [string]$EC2_IP = "98.92.230.238",
    [int]$Port = 8080,
    [int]$MaxAttempts = 20,
    [int]$WaitSeconds = 30
)

Write-Host "🔍 Monitoring EC2 API at $EC2_IP:$Port" -ForegroundColor Green
Write-Host "Will check every $WaitSeconds seconds for up to $MaxAttempts attempts" -ForegroundColor Yellow
Write-Host ""

$attempt = 1
$apiReady = $false

while ($attempt -le $MaxAttempts -and -not $apiReady) {
    Write-Host "[$attempt/$MaxAttempts] Checking EC2 API..." -ForegroundColor Cyan
    
    try {
        # Test network connectivity first
        $tcpTest = Test-NetConnection -ComputerName $EC2_IP -Port $Port -WarningAction SilentlyContinue
        
        if ($tcpTest.TcpTestSucceeded) {
            Write-Host "✅ Port $Port is accessible" -ForegroundColor Green
            
            # Test API health endpoint
            $response = Invoke-RestMethod -Uri "http://$EC2_IP:$Port/health" -Method GET -ContentType "application/json" -TimeoutSec 10
            
            Write-Host "🎉 SUCCESS! EC2 API is ready!" -ForegroundColor Green
            Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor White
            Write-Host ""
            Write-Host "=== EC2 API READY ===" -ForegroundColor Green
            Write-Host "Health Check: http://$EC2_IP:$Port/health" -ForegroundColor Yellow
            Write-Host "Prediction: http://$EC2_IP:$Port/predict" -ForegroundColor Yellow
            Write-Host "Model Info: http://$EC2_IP:$Port/model-info" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Ready for Postman testing with base URL: http://$EC2_IP:$Port" -ForegroundColor Magenta
            
            $apiReady = $true
        } else {
            Write-Host "❌ Port $Port not accessible yet" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ API not ready: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    if (-not $apiReady) {
        if ($attempt -lt $MaxAttempts) {
            Write-Host "⏳ Waiting $WaitSeconds seconds before next check..." -ForegroundColor Yellow
            Start-Sleep -Seconds $WaitSeconds
        }
        $attempt++
    }
}

if (-not $apiReady) {
    Write-Host ""
    Write-Host "⚠️ EC2 API did not become ready within the timeout period" -ForegroundColor Yellow
    Write-Host "This could be due to:" -ForegroundColor White
    Write-Host "- Docker container still starting up" -ForegroundColor White
    Write-Host "- Security group configuration" -ForegroundColor White
    Write-Host "- Instance initialization still in progress" -ForegroundColor White
    Write-Host ""
    Write-Host "Meanwhile, you can test locally with: http://localhost:8080" -ForegroundColor Cyan
}