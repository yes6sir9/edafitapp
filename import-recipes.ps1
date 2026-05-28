# PowerShell script to import recipes from Recepts.csv to Firestore
# Usage: powershell -ExecutionPolicy Bypass -File import-recipes.ps1

$projectId = "edafit-f3738"
$csvPath = "./Recepts.csv"
$idToken = $null

# Функция для получения ID токена
function Get-IdToken {
    Write-Host "Получаем токен доступа..." -ForegroundColor Cyan
    
    # Используем firebase CLI для получения токена
    $tokenOutput = firebase auth:export --format=json 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Не удалось получить токен через firebase CLI" -ForegroundColor Yellow
        Write-Host "Пожалуйста, используйте браузер для входа в Firebase Console"
        Write-Host "Переходите на: https://console.firebase.google.com/project/$projectId/firestore"
        exit 1
    }
    
    return $tokenOutput
}

# Функция для парсинга CSV строки (с поддержкой кавычек)
function Parse-CsvLine {
    param([string]$line)
    
    $parts = @()
    $current = ""
    $inQuotes = $false
    
    for ($i = 0; $i -lt $line.Length; $i++) {
        $char = $line[$i]
        
        if ($char -eq '"') {
            $inQuotes = -not $inQuotes
        }
        elseif ($char -eq ',' -and -not $inQuotes) {
            $parts += $current
            $current = ""
        }
        else {
            $current += $char
        }
    }
    
    if ($current) {
        $parts += $current
    }
    
    # Убираем кавычки и пробелы
    return $parts | ForEach-Object { $_.Trim() -replace '"', '' }
}

# Функция для парсинга БЖУ
function Parse-Macros {
    param([string]$macrosText)
    
    $macros = @{
        protein = ""
        fat = ""
        carbs = ""
    }
    
    if ($macrosText -match "Белки:\s*([\d.,]+)\s*г") {
        $macros.protein = $matches[1]
    }
    if ($macrosText -match "Жиры:\s*([\d.,]+)\s*г") {
        $macros.fat = $matches[1]
    }
    if ($macrosText -match "Углеводы:\s*([\d.,]+)\s*г") {
        $macros.carbs = $matches[1]
    }
    
    return $macros
}

# Функция для добавления документа в Firestore через REST API
function Add-RecipeToFirestore {
    param(
        [string]$title,
        [string]$type,
        [string]$products,
        [string]$calories,
        [string]$instructions,
        [hashtable]$macros,
        [int]$index
    )
    
    try {
        $docId = $title.ToLower() -replace '\s+', '_' -replace '[^\w_а-яё]', ''
        
        $recipeData = @{
            id = $index
            title = $title
            type = $type
            products = $products
            calories = $calories
            instructions = $instructions
            macros = @{
                protein = $macros.protein
                fat = $macros.fat
                carbs = $macros.carbs
            }
        } | ConvertTo-Json
        
        # REST API URL для Firestore
        $url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/recipes/$docId"
        
        # Пытаемся добавить через REST API (требует аутентификации)
        $response = Invoke-RestMethod -Uri $url `
            -Method Patch `
            -ContentType "application/json" `
            -Body $recipeData `
            -ErrorAction Stop
        
        Write-Host "✅ Рецепт $index/$totalRecipes: `"$title`" добавлен" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Ошибка при добавлении рецепта $index: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Основной скрипт
Write-Host "🚀 Начинаем импорт рецептов..." -ForegroundColor Cyan

if (-not (Test-Path $csvPath)) {
    Write-Host "❌ Файл $csvPath не найден" -ForegroundColor Red
    exit 1
}

# Читаем CSV файл
$lines = Get-Content $csvPath -Encoding UTF8
$totalRecipes = $lines.Count - 1  # Минус заголовок

Write-Host "📋 Найдено $totalRecipes рецептов" -ForegroundColor Cyan

$successCount = 0
$errorCount = 0

# Пропускаем заголовок и обрабатываем рецепты
for ($i = 1; $i -lt $lines.Count; $i++) {
    try {
        $parts = Parse-CsvLine $lines[$i]
        
        if ($parts.Count -lt 6) {
            Write-Host "⚠️  Некорректная строка $($i + 1): недостаточно полей" -ForegroundColor Yellow
            continue
        }
        
        $title = $parts[0]
        $type = $parts[1]
        $products = $parts[2]
        $calories = $parts[3]
        $instructions = $parts[4]
        $macrosText = $parts[5]
        
        $macros = Parse-Macros $macrosText
        
        # Пока просто выводим информацию (REST API требует аутентификации)
        Write-Host "📝 Рецепт $i/$totalRecipes: $title (Тип: $type, Калории: $calories)" -ForegroundColor White
        $successCount++
    }
    catch {
        Write-Host "❌ Ошибка при обработке строки $($i + 1): $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "⚠️  ВАЖНО: Этот скрипт показал предпросмотр данных." -ForegroundColor Yellow
Write-Host "Для непосредственного импорта в Firestore используйте одно из решений:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  Используйте Node.js скрипт (рекомендуется):" -ForegroundColor Cyan
Write-Host "   cd functions" -ForegroundColor Cyan
Write-Host "   npm install" -ForegroundColor Cyan
Write-Host "   npm run import" -ForegroundColor Cyan
Write-Host ""
Write-Host "2️⃣  Импортируйте через Firebase Console:" -ForegroundColor Cyan
Write-Host "   https://console.firebase.google.com/project/$projectId/firestore" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Результаты предпросмотра:" -ForegroundColor Cyan
Write-Host "✅ Рецептов для импорта: $successCount" -ForegroundColor Green
Write-Host "❌ Ошибок: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
