const { onCall } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { GoogleGenerativeAI } = require("@google/generative-ai");

initializeApp();

const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
const db = getFirestore();

/**
 * Cloud Function для импорта рецептов из CSV данных
 * Принимает массив рецептов и добавляет их в Firestore
 */
exports.importRecipes = onCall(async (request) => {
  const recipes = request.data?.recipes ?? [];

  if (!Array.isArray(recipes) || recipes.length === 0) {
    throw new Error("Recipes array is empty or invalid");
  }

  try {
    console.log(`Начинаем импорт ${recipes.length} рецептов...`);
    
    const batch = db.batch();
    let count = 0;

    for (const recipe of recipes) {
      try {
        // Нормализуем ID документа
        const docId = (recipe.title || `recipe_${count}`)
          .toLowerCase()
          .replace(/\s+/g, '_')
          .replace(/[^\w_а-яё]/g, '');

        // Структурируем данные
        const recipeData = {
          id: count + 1,
          title: recipe.title?.trim() || '',
          type: recipe.type?.trim() || '',
          products: recipe.products?.trim() || '',
          calories: recipe.calories?.trim() || '',
          instructions: recipe.instructions?.trim() || '',
          macros: recipe.macros || {
            protein: '',
            fat: '',
            carbs: '',
          },
          createdAt: new Date(),
          updatedAt: new Date(),
        };

        const docRef = db.collection('recipes').doc(docId);
        batch.set(docRef, recipeData);
        count++;

        console.log(`✅ Рецепт ${count}/${recipes.length}: "${recipeData.title}" готов к импорту`);
      } catch (error) {
        console.error(`⚠️  Ошибка обработки рецепта:`, error);
      }
    }

    // Коммитим батч
    await batch.commit();

    return {
      success: true,
      message: `Успешно импортировано ${count} рецептов`,
      count: count,
    };
  } catch (error) {
    console.error("Error importing recipes:", error);
    throw new Error(`Failed to import recipes: ${error.message}`);
  }
});

/**
 * Cloud Function для взаимодействия с Google Gemini API
 * Принимает промпт и возвращает ответ от Gemini
 */
exports.askAi = onCall(async (request) => {
  const prompt = request.data?.prompt ?? "";

  // Проверка на пустой промпт
  if (!prompt.trim()) {
    throw new Error("Prompt is empty");
  }

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-pro" });

    // Отправка запроса в Gemini API
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    // Возврат результата
    return {
      text: text,
      success: true,
    };
  } catch (error) {
    console.error("Error calling Gemini API:", error);
    throw new Error(`Failed to get AI response: ${error.message}`);
  }
});

/**
 * Cloud Function для проверки здоровья сервиса
 */
exports.health = onCall(async () => {
  return {
    status: "ok",
    timestamp: new Date().toISOString(),
  };
});
