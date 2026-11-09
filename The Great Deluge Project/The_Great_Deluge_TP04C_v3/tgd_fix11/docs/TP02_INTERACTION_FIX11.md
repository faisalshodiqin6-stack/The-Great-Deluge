# TP-02 Fix 11 — Stabilitas Deteksi Interaksi

Perubahan:
- Deteksi item memakai sphere proximity query pada physics layer 3.
- Menghapus pemeriksaan line-of-sight kedua yang dapat tertutup collider terrain untuk item rendah.
- Tidak mewajibkan kamera tepat mengarah ke tengah item; item terdekat dalam radius diprioritaskan.
- Tombol E menghitung ulang target sebelum memanggil `interact()`.

Catatan validasi: arsip dan referensi file diperiksa secara statis. Pengujian runtime Godot tetap perlu dilakukan.
