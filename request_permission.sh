#!/bin/bash
# Скрипт для запроса разрешения автоматизации

echo "Этот скрипт поможет запросить разрешение автоматизации для Orbit"
echo ""
echo "Вариант 1: Сброс разрешений (рекомендуется)"
echo "Выполните в терминале:"
echo "  tccutil reset AppleEvents"
echo ""
echo "Вариант 2: Проверка текущих разрешений"
echo "Выполните в терминале:"
echo "  sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \"SELECT * FROM access WHERE client LIKE '%Orbit%';\""
echo ""
echo "Вариант 3: Вручную через System Settings"
echo "1. Откройте System Settings → Privacy & Security → Automation"
echo "2. Найдите Orbit в списке"
echo "3. Включите разрешение для Safari/Chrome"
