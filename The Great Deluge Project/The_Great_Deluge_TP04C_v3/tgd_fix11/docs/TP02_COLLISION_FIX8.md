# TP-02 Fix 8 — Terrain Collision Stabilization

## Perubahan
- Mempertahankan mesh visual pulau dari Fix 7.
- Mengganti collision `ConcavePolygonShape3D`/trimesh menjadi `HeightMapShape3D` dengan grid 1 meter.
- Heightmap mengambil tinggi dari fungsi terrain yang sama dengan mesh visual.
- Area pusat (`PLATEAU_RADIUS`) dipertahankan datar pada Y=9 agar spawn dan pergerakan awal stabil.
- Area di luar garis pantai visual diberi seabed sementara pada Y=-1, agar pemain tidak jatuh tanpa batas di sekitar pulau.
- Posisi spawn tetap `(0, 12, 0)`. Capsule tetap berukuran 0.42 x 1.8. Lompatan SPACE dari Fix 7 tetap dipertahankan.

## Layer collision
- Layer 1: terrain pulau.
- Layer 2: pemain.
- Layer 3: objek interaksi.

## Validasi
- Pemeriksaan statis dilakukan pada path scene, skrip, dan struktur ZIP.
- Belum diuji dengan menjalankan Godot 4 secara langsung di lingkungan pembuat paket.

## Catatan
Heightmap grid menggunakan jarak 1 meter. Ini sedikit menyederhanakan permukaan collider dibanding mesh visual, tetapi menghindari banyak sambungan segitiga kecil pada collider trimesh.
