# 🔐 Настройка Firestore правил безопасности

## ⚠️ Проблема

Рецепты не добавляются в Firebase Firestore. Вероятная причина - неправильные правила безопасности.

## ✅ Решение

### Шаг 1: Откройте Firebase Console

1. Перейдите на [https://console.firebase.google.com](https://console.firebase.google.com)
2. Выберите проект `edafit-f3738`
3. В левом меню найдите **Firestore Database**
4. Откройте вкладку **Rules** (Правила)

### Шаг 2: Замените правила

Замените текущие правила на следующие:

```yaml
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Позволяем читать и писать в коллекцию recipes для любых пользователей
    match /recipes/{document=**} {
      allow read: if true;
      allow write: if true;
    }
  }
}
```

### Шаг 3: Опубликуйте правила

Нажмите кнопку **Publish** (Опубликовать)

⚠️ **Внимание**: Эти правила позволяют ЛЮБОМУ писать в Firestore. 
Для продакшена используйте более строгие правила с аутентификацией.

---

## 🔒 Безопасные правила (для продакшена)

Если ваше приложение использует аутентификацию:

```yaml
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Аутентифицированные пользователи могут читать рецепты
    match /recipes/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

Или только для чтения, администраторы могут писать:

```yaml
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /recipes/{document=**} {
      allow read: if true;
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
  }
}
```

---

## 📱 Проверка в приложении

После обновления правил, запустите импорт:

1. Откройте приложение
2. Перейдите на экран импорта рецептов
3. Нажмите "Начать импорт"
4. Проверьте консоль для ошибок
5. После успеха, откройте Firebase Console и проверьте коллекцию `recipes`

---

## 🐛 Отладка

### Проверка логов в Firestore

1. Перейдите в **Firestore Database**
2. Откройте **Logs** (Логи)
3. Проверьте ошибки безопасности (Security rules denied)

### Логи в приложении

Откройте Android Studio или VS Code и проверьте вывод консоли при импорте.

### Проверка подключения Firebase

```dart
// Добавьте в main.dart для проверки
print('Firebase initialized: ${Firebase.apps.length > 0}');
print('Firestore: ${FirebaseFirestore.instance}');
```

---

## ✨ Дополнительно

Если после этого рецепты все еще не появляются:

1. **Очистите Firestore**: Удалите коллекцию `recipes` если она создана
2. **Перезагрузитесь**: Закройте и откройте приложение заново
3. **Проверьте сеть**: Убедитесь что приложение имеет интернет
4. **Логи ошибок**: Проверьте полный вывод ошибки в консоли

---

## 📞 Чек-лист

- [ ] Открыл Firebase Console
- [ ] Выбрал проект edafit-f3738
- [ ] Перешел в Firestore Database → Rules
- [ ] Заменил правила на новые
- [ ] Нажал Publish
- [ ] Запустил приложение
- [ ] Нажал "Начать импорт"
- [ ] Проверил Firebase Console для новых документов

**Готово!** 🚀
