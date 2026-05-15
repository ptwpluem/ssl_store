const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// Run automatically every 1 hour to reduce costs
exports.scrapeGoldPrice = onSchedule("every 1 hours", async (event) => {
  try {
    // Using a reliable Thai gold prices API endpoint
    const url = "https://api.chnwt.dev/thai-gold-api/latest";
    const response = await axios.get(url, {
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0'
      }
    });

    const data = response.data;

    // We specifically want the "Gold Bar" (ทองคำแท่ง) price for the baseline rate
    let buyPrice = 0;
    let sellPrice = 0;
    let updateTime = "";

    // The API responds with:
    // {"status":"success","response":{"date":"2024-03-01","update_time":"16:50","price":{"gold":{"buy":"...","sell":"..."},"gold_bar":{"buy":"74,900.00","sell":"75,100.00"}}}}
    if (data && data.status === "success" && data.response && data.response.price && data.response.price.gold_bar) {
      const gb = data.response.price.gold_bar;
      buyPrice = parseInt(gb.buy.replace(/,/g, ''), 10);
      sellPrice = parseInt(gb.sell.replace(/,/g, ''), 10);
      updateTime = data.response.update_time || "";
    } else {
      console.error("Failed to parse the new structure from API response.", data);
      return null;
    }

    if (isNaN(buyPrice) || isNaN(sellPrice) || buyPrice < 10000) {
      console.error("Failed to parse valid prices:", buyPrice, sellPrice);
      return null;
    }

    const db = admin.firestore();
    const docRef = db.collection("market").doc("gold_rate");

    // Read current price before overwriting to compute real trend direction
    const currentDoc = await docRef.get();
    const previousBuy = currentDoc.exists ? (currentDoc.data().buyPrice || buyPrice) : buyPrice;
    const newTrend = buyPrice > previousBuy ? "up" : buyPrice < previousBuy ? "down" : "stable";

    await docRef.set({
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      updateTime: updateTime,
      trend: newTrend
    }, { merge: true });

    console.log(`Updated gold price. Buy: ${buyPrice}, Sell: ${sellPrice}`);
    return null;

  } catch (error) {
    console.error("Error scraping gold price:", error);
    return null;
  }
});
