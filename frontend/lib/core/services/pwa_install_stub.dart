// No-op PWA install support off the web (Dart VM / tests). Installing an app
// only makes sense in a browser.
void initPwaInstall() {}

void setPwaChangeListener(void Function()? cb) {}

bool pwaInstallAvailable() => false;

Future<void> promptPwaInstall() async {}
