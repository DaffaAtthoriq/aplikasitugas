import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// Widget utama aplikasi
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do & Notes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false, // Menghilangkan banner debug
    );
  }
}

// Model data sederhana untuk menyimpan catatan
class NoteItem {
  String title;
  bool isDone;

  NoteItem({required this.title, this.isDone = false});
}

// Halaman utama (Stateful karena datanya bisa berubah-ubah)
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Menyimpan daftar catatan di dalam memori sementara
  List<NoteItem> notes = [];
  
  // Controller untuk mengambil teks dari inputan pengguna
  final TextEditingController _textController = TextEditingController();

  // Fungsi untuk menambahkan catatan baru
  void _addNote() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        notes.add(NoteItem(title: _textController.text));
      });
      _textController.clear(); // Bersihkan kolom teks setelah ditambah
      Navigator.pop(context); // Tutup popup dialog
    }
  }

  // Fungsi untuk memunculkan popup dialog input
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Catatan / Tugas'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(hintText: "Tulis sesuatu di sini..."),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _textController.clear();
                Navigator.pop(context); // Batal dan tutup
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: _addNote,
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan & Tugas-ku'),
        centerTitle: true,
      ),
      // Menampilkan daftar catatan
      body: notes.isEmpty
          ? const Center(child: Text('Belum ada catatan. Yuk tambah!'))
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    // Checkbox untuk menandai selesai/belum
                    leading: Checkbox(
                      value: note.isDone,
                      onChanged: (bool? value) {
                        setState(() {
                          note.isDone = value!;
                        });
                      },
                    ),
                    title: Text(
                      note.title,
                      style: TextStyle(
                        // Memberi efek coret jika sudah selesai
                        decoration: note.isDone 
                            ? TextDecoration.lineThrough 
                            : TextDecoration.none,
                      ),
                    ),
                    // Tombol hapus
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          notes.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
      // Tombol mengambang di pojok kanan bawah
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
