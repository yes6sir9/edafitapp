# Локальный RAG для рецептов

Этот проект использует локальную модель через Ollama для AI-чата на странице рецептов.

## 1) Установка Ollama (Windows)

```powershell
winget install -e --id Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements
```

## 2) Запуск Ollama и загрузка модели

```powershell
ollama serve
ollama pull llama3.1:8b
```

## 3) Как работает RAG в приложении

- Рецепты берутся из Firestore (`recipes`).
- Сначала применяется фильтрация под цель пользователя (калории/белок).
- Затем retrieval выбирает top-K рецептов под запрос.
- В локальную LLM передается только этот контекст.
- Модель отвечает только на основе найденных рецептов.

## 4) Если чат пишет "Локальная ИИ не запущена"

Проверьте:

1. Процесс Ollama запущен (`ollama serve`).
2. Модель загружена (`ollama pull llama3.1:8b`).
3. Локальный API доступен на `http://127.0.0.1:11434`.
