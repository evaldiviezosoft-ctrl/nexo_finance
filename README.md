# Nexo Finance

Aplicación móvil personal de control financiero para Perú. La base usa Flutter,
Material 3, Riverpod y Firebase, con interfaz AMOLED y montos almacenados como
enteros en la unidad monetaria mínima.

## Estado

Fases 1 a 6 implementadas:

- arquitectura por funcionalidades (`app`, `core`, `features`);
- tema AMOLED centralizado y navegación inferior con acceso rápido;
- Firebase Core, Authentication, Firestore offline y App Check;
- acceso protegido con correo/contraseña y Google;
- pantalla segura de configuración cuando faltan credenciales;
- modelos inmutables con Freezed y serialización JSON;
- reglas Firestore con aislamiento por usuario y validación por colección;
- configuración regional `es_PE`, PEN/USD y `America/Lima` como contrato;
- tipo `Money` basado exclusivamente en unidades menores;
- cuentas PEN/USD con saldo inicial, edición y archivado;
- categorías y subcategorías editables, con catálogo inicial;
- gastos, ingresos, transferencias, tarjetas, préstamos, metas y reembolsos;
- edición, duplicado, búsqueda, borrado lógico y deshacer de movimientos;
- saldos, patrimonio, deuda e ingresos/gastos derivados del libro mayor;
- transferencias entre monedas conservando ambos importes y el cambio implícito;
- estado de sincronización pendiente/sincronizado mediante metadatos Firestore.
- presupuestos diarios, semanales, mensuales y personalizados, globales o por
  categoría, con progreso, restante, proyección y alertas 70/90/100%;
- ciclos de tarjetas que separan deuda total, pago del ciclo PEN/USD, crédito
  disponible y dinero reservado;
- días fijos de cierre y pago por tarjeta;
- recurrencias semanales, mensuales y anuales que requieren confirmación antes
  de crear un movimiento real;
- panel con saldo libre de reservas, presupuesto disponible y próximos pagos.
- metas con saldo inicial reservado, cuenta asociada, prioridad, fecha objetivo,
  aporte recomendado, ritmo real, fecha estimada y retiros opcionales;
- deudas propias y dinero por cobrar con acreedor/deudor, tasa, cuotas, fechas,
  aportes de terceros y saldo reconstruido desde pagos o cobros;
- simulador de deuda que compara el plan normal con prepago y aportes mensuales
  extra, incluyendo ahorro de intereses y reducción de plazo.
- reportes interactivos de ingresos, gastos, ahorro, ritmo diario, categorías,
  deudas y metas, con filtros de periodo y moneda;
- dashboard con periodos semanal, mensual, últimos tres meses, anual y rango
  personalizado;
- exportación de movimientos CSV, reporte mensual PDF y copia completa JSON,
  con rango de fechas y opción para ocultar información personal.
- importación validada de copias JSON, sin eliminar registros ausentes;
- bloqueo biométrico opcional y preferencia cifrada para ocultar saldos;
- recordatorios locales de tarjetas, cuotas, recurrencias y metas;
- diagnóstico de sincronización y modo sin conexión;
- limpieza de caché y eliminación de cuenta con doble confirmación.

## Primer uso

1. Inicia sesión.
2. Abre **Ajustes → Cuentas → Nueva cuenta**.
3. Registra el dinero que ya posees como **saldo inicial**. No se contabiliza
   como ingreso.
4. Abre **Ajustes → Categorías** para editar el catálogo o crear categorías y
   subcategorías.
5. Usa el botón rojo `+` para registrar un movimiento.
6. Abre **Plan** para crear límites, registrar ciclos de tarjeta, reservar
   dinero y configurar movimientos recurrentes.
7. Abre **Ajustes → Notificaciones** para conceder permiso y programar avisos.
8. Abre **Ajustes → Seguridad** para activar biometría u ocultar saldos.

Los ingresos representan dinero nuevo (sueldo, ventas, etc.). Una compra con
tarjeta cuenta como gasto al comprar; pagar la tarjeta solo reduce cuenta y
deuda. Transferencias, aportes a metas y devoluciones de préstamos no se tratan
como ingresos o gastos nuevos.

## Requisitos

- Flutter 3.38.6 o compatible (canal estable)
- Dart 3.10.7 o compatible
- Node.js y Firebase CLI para emuladores
- FlutterFire CLI

## Configuración local

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

El identificador Android actual es provisional:
`com.example.nexo_finance`. Cámbialo por el identificador definitivo antes de
registrar las aplicaciones en Firebase.

## Configurar Firebase

1. Crea un proyecto en Firebase Console.
2. Instala las herramientas:

   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```

3. Desde la raíz, ejecuta:

   ```bash
   flutterfire configure --platforms=android,ios
   ```

4. En Authentication habilita **Email/Password** y **Google**.
5. Crea Cloud Firestore. La app activa persistencia local; las escrituras se
   mantienen pendientes y se sincronizan al recuperar conexión.
6. Registra Android/iOS en App Check. En depuración se usa el proveedor debug;
   en release se usan Play Integrity y App Attest.
7. Despliega reglas e índices:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

`google-services.json`, `GoogleService-Info.plist`, `.firebaserc` y
`firebase_options.dart` están ignorados. Un checkout nuevo debe ejecutar
`flutterfire configure` antes de compilar. Distribuye esos archivos por un
canal privado o CI si no deseas regenerarlos.

### Google Sign-In

En Android agrega las huellas SHA-1 y SHA-256 de debug/release en Firebase. En
iOS sigue la configuración de URL schemes generada para Google Sign-In. El
botón no funcionará hasta habilitar el proveedor y completar esos registros.

## Modelo de seguridad

Los datos viven bajo `users/{uid}/...`. Las reglas:

- no permiten lecturas globales;
- verifican que el usuario autenticado coincida con la ruta;
- exigen `id`, `userId`, `version`, `createdAt` y `updatedAt`;
- permiten borrado físico únicamente al propietario para la eliminación total
  solicitada desde la pantalla de privacidad;
- usan `deletedAt` para el borrado cotidiano sincronizable.

Usa `FieldValue.serverTimestamp()` para `createdAt/updatedAt`. La estrategia de
conflictos prevista es actualización optimista, `version` incremental y última
escritura válida por `updatedAt`, conservando estados sincronizado, pendiente y
error. Los resúmenes son reconstruibles desde movimientos.

## Emuladores

```bash
firebase emulators:start --only auth,firestore
```

Para ejecutar las pruebas de aislamiento y borrado autorizado:

```bash
npm install --prefix firestore-tests
firebase emulators:exec --only firestore "npm --prefix firestore-tests test"
```

Los puertos están declarados en `firebase.json` (Auth 9099, Firestore 8080 y UI
4000). Las reglas validan los campos esenciales de cada colección y aíslan los
documentos por `uid`.

## Calidad

```bash
dart format .
flutter analyze
flutter test
```

Para regenerar modelos:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Builds

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

Los builds release requieren firma, archivos Firebase del entorno y App Check
registrado. Nunca guardes claves, contraseñas ni tokens en Firestore o Git.

## Copias y privacidad

- Importar acepta solamente copias JSON válidas y no anonimizadas.
- La importación combina por identificador y nunca elimina registros ausentes.
- Borrar caché conserva la información sincronizada en Firebase.
- Eliminar cuenta exige una sesión reciente, dos confirmaciones y escribir
  `ELIMINAR`.
