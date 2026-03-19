package com.queueit.retaildemo.model;

/**
 * POJO matching the JSON structure returned by
 * https://retail.queue-it-demo.com/api/productList.json
 *
 * The `icon` field contains an SF Symbol name from iOS.
 * We map it to a display emoji in the adapter.
 */
public class Product {
    public String name;
    public String price;
    public String icon;        // SF Symbol name (mapped to emoji on Android)
    public String product_id;

    /**
     * Maps iOS SF Symbol icon names to display emoji for Android.
     * Returns 🛍️ for any unknown symbol.
     */
    public String getIconEmoji() {
        if (icon == null) return "🛍️";
        switch (icon) {
            case "desktopcomputer":
            case "laptopcomputer":        return "💻";
            case "gamecontroller":
            case "gamecontroller.fill":   return "🎮";
            case "headphones":            return "🎧";
            case "tv":
            case "tv.fill":               return "📺";
            case "iphone":
            case "smartphone":            return "📱";
            case "applewatch":
            case "watch":                 return "⌚";
            case "camera":
            case "camera.fill":           return "📷";
            case "keyboard":              return "⌨️";
            case "computermouse":
            case "computermouse.fill":    return "🖱️";
            case "printer":
            case "printer.fill":          return "🖨️";
            case "speaker":
            case "speaker.fill":
            case "hifispeaker":           return "🔊";
            case "bolt":
            case "bolt.fill":             return "⚡";
            case "cart":
            case "cart.fill":             return "🛒";
            case "bag":
            case "bag.fill":              return "🛍️";
            case "gift":
            case "gift.fill":             return "🎁";
            case "tshirt":
            case "tshirt.fill":           return "👕";
            case "shoe":
            case "shoe.fill":             return "👟";
            case "star":
            case "star.fill":             return "⭐";
            default:                      return "🛍️";
        }
    }
}
