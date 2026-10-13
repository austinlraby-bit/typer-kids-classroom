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
  // GitHub Pages may retain the compiled JavaScript briefly even after a new
  // deployment. Version the entrypoint independently so classroom iPads do
  // not combine a fresh shell with an older application bundle.
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath === 'main.dart.js') {
      build.mainJsPath = 'main.dart.js?v=20261013-finger-reach';
    }
  }
  await _flutter.loader.load();
})();
