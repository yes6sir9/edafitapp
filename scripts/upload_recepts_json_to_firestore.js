const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'edafit-f3738';
const API_KEY = 'AIzaSyBs7LZBr2P0_5m_JUThhx54yAdRZuyYeZ8';
const COLLECTION = 'recipes';

function parseMacros(macrosText = '') {
  const protein = (macrosText.match(/Белки:\s*([\d.,–-]+)\s*г/i) || [,''])[1].trim();
  const fat = (macrosText.match(/Жиры:\s*([\d.,–-]+)\s*г/i) || [,''])[1].trim();
  const carbs = (macrosText.match(/Углеводы:\s*([\d.,–-]+)\s*г/i) || [,''])[1].trim();
  return { protein, fat, carbs };
}

function normalizeDocId(title) {
  return title
    .toLowerCase()
    .replace(/\s+/g, '_')
    .replace(/[^\w_а-яё]/gi, '')
    .slice(0, 100);
}

async function clearCollection() {
  const listUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}?pageSize=500&key=${API_KEY}`;
  const listRes = await fetch(listUrl);
  const listJson = await listRes.json();
  const docs = listJson.documents || [];

  for (const doc of docs) {
    const deleteUrl = `https://firestore.googleapis.com/v1/${doc.name}?key=${API_KEY}`;
    await fetch(deleteUrl, { method: 'DELETE' });
  }

  return docs.length;
}

function toFirestoreFields(recipe, index) {
  const macros = parseMacros(recipe['БЖУ'] || '');
  return {
    id: { integerValue: String(index + 1) },
    title: { stringValue: (recipe['Название'] || '').trim() },
    type: { stringValue: (recipe['Тип'] || '').trim() },
    products: { stringValue: (recipe['Продукты'] || '').trim() },
    calories: { stringValue: (recipe['Килакалории'] || '').trim() },
    instructions: { stringValue: (recipe['Подробное описание приготовление'] || '').trim() },
    macros: {
      mapValue: {
        fields: {
          protein: { stringValue: macros.protein },
          fat: { stringValue: macros.fat },
          carbs: { stringValue: macros.carbs },
        },
      },
    },
    createdAt: { timestampValue: new Date().toISOString() },
    updatedAt: { timestampValue: new Date().toISOString() },
  };
}

async function upload() {
  const filePath = path.join(__dirname, '..', 'Recepts.json');
  const raw = fs.readFileSync(filePath, 'utf-8');
  const recipes = JSON.parse(raw);

  console.log(`Found ${recipes.length} recipes in Recepts.json`);
  const deletedCount = await clearCollection();
  console.log(`Cleared existing documents: ${deletedCount}`);

  let success = 0;
  let failed = 0;

  for (let i = 0; i < recipes.length; i += 1) {
    const recipe = recipes[i];
    const title = (recipe['Название'] || '').trim();
    const docId = `${i + 1}_${normalizeDocId(title || `recipe_${i + 1}`)}`;
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}/${encodeURIComponent(docId)}?key=${API_KEY}`;

    const body = JSON.stringify({
      fields: toFirestoreFields(recipe, i),
    });

    const res = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body,
    });

    if (res.ok) {
      success += 1;
      console.log(`OK ${i + 1}/${recipes.length}: ${title}`);
    } else {
      failed += 1;
      const text = await res.text();
      console.log(`FAIL ${i + 1}/${recipes.length}: ${title}`);
      console.log(text);
    }
  }

  console.log(`Done. Success: ${success}, Failed: ${failed}`);
  if (failed > 0) process.exit(1);
}

upload().catch((err) => {
  console.error(err);
  process.exit(1);
});
