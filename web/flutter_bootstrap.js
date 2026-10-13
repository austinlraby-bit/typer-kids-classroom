{{flutter_js}}
{{flutter_build_config}}

(async () => {
  // GitHub Pages previously served a cache-first Flutter service worker.
  // Remove only Flutter's caches so classroom iPads receive current builds.
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map((registration) => registration.unregister()));
  }
  if ('caches' in window) {
    const names = await caches.keys();
    await Promise.all(
      names
        .filter((name) => name.startsWith('flutter-app-cache') || name.startsWith('flutter-temp-cache'))
        .map((name) => caches.delete(name)),
    );
  }
  await _flutter.loader.load();
})();
