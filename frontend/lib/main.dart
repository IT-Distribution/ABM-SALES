import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/best_route_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

// Remplacer par l'URL de ton backend FastAPI
const String backendUrl = 'http://localhost:8000'; // Utiliser localhost au lieu de 10.0.2.2

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABM Sales',
      theme: ThemeData(
        primaryColor: const Color(0xFF7AB828),
        primarySwatch: MaterialColor(0xFF7AB828, {
          50: Color(0xFFF2F8E7),
          100: Color(0xFFE0F0C2),
          200: Color(0xFFCCE699),
          300: Color(0xFFB7DB70),
          400: Color(0xFFA7D34F),
          500: Color(0xFF7AB828),
          600: Color(0xFF6EA321),
          700: Color(0xFF5E8B1B),
          800: Color(0xFF4E7315),
          900: Color(0xFF3E5B0F),
        }),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF7AB828),
          elevation: 2,
          iconTheme: IconThemeData(color: Color(0xFF7AB828)),
          titleTextStyle: TextStyle(
            color: Color(0xFF7AB828),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7AB828),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/map': (context) => const MapScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  String? _userEmail; // Nouvelle variable pour stocker l'email de l'utilisateur

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Pas de déconnexion forcée au démarrage
    // await _authService.logout(); 
    final isLoggedIn = await _authService.isLoggedIn();
    final isAdmin = await _authService.isAdmin();
    final userEmail = await _authService.getUserEmail();

    setState(() {
      _isLoggedIn = isLoggedIn;
      _isAdmin = isAdmin;
      _userEmail = userEmail;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn && _userEmail != null) {
      return MainTabsPage(isAdmin: _isAdmin, userEmail: _userEmail!); // Passer l'email ici
    } else {
      return const LoginScreen();
    }
  }
}

// Nouvelle classe pour gérer les onglets
class MainTabsPage extends StatefulWidget {
  final bool isAdmin;
  final String userEmail;

  const MainTabsPage({Key? key, required this.isAdmin, required this.userEmail}) : super(key: key);

  @override
  _MainTabsPageState createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<_ImportsListPageState> importsListKey = GlobalKey<_ImportsListPageState>();
  final GlobalKey<_MapPageState> _mapPageKey = GlobalKey<_MapPageState>();
  Set<int> _selectedImportIdsForCalculation = {};
  int _nombreVendeursNecessaires = 0; // Nouvelle variable pour stocker le nombre de vendeurs nécessaires
  
  @override
  void initState() {
    super.initState();
    // Le nombre d'onglets dépend du rôle de l'utilisateur
    _tabController = TabController(length: widget.isAdmin ? 4 : 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void goToListTab() {
    print("Redirection vers l'onglet Listes de fichiers...");
    // Attendre un court instant pour s'assurer que l'import est terminé
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      // Passer à l'onglet "Listes de fichiers"
      _tabController.animateTo(1);
      // Forcer le rechargement de la liste
      print("Rechargement de la liste des fichiers...");
      importsListKey.currentState?.fetchImports();
    });
  }
  
  // Callback pour recevoir les IDs sélectionnés de ImportsListPage
  void onImportsSelected(Set<int> selectedIds) {
    setState(() {
      _selectedImportIdsForCalculation = selectedIds;
    });
    // Passer à l'onglet "Calcule"
    _tabController.animateTo(2);
  }
  
  // Méthode pour mettre à jour le nombre de vendeurs nécessaires
  void updateNombreVendeursNecessaires(int nombre) {
    setState(() {
      _nombreVendeursNecessaires = nombre;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Définir les onglets en fonction du rôle
    final List<Tab> tabs = widget.isAdmin
        ? const [
            Tab(icon: Icon(Icons.upload_file), text: 'Upload'),
            Tab(icon: Icon(Icons.list), text: 'Listes de fichiers'),
            Tab(icon: Icon(Icons.calculate), text: 'Calcule'),
            Tab(icon: Icon(Icons.map), text: 'Carte'),
          ]
        : const [
            Tab(icon: Icon(Icons.map), text: 'Carte'),
            Tab(icon: Icon(Icons.alt_route), text: 'Mon Trajet'),
          ];

    final List<Widget> tabViews = widget.isAdmin
        ? [
            UploadPage(onUploadSuccess: goToListTab),
            ImportsListPage(key: importsListKey, onContinue: onImportsSelected),
            CalculePage(
              selectedImportIds: _selectedImportIdsForCalculation,
              onVendeursCalculated: updateNombreVendeursNecessaires,
            ),
            MapPage(
              key: _mapPageKey,
              selectedImportIds: _selectedImportIdsForCalculation,
              initialNombreZones: _nombreVendeursNecessaires,
              isAdmin: widget.isAdmin,
              userEmail: widget.userEmail,
            ),
          ]
        : [
            MapPage(
              key: _mapPageKey,
              selectedImportIds: _selectedImportIdsForCalculation,
              initialNombreZones: _nombreVendeursNecessaires,
              isAdmin: widget.isAdmin,
              userEmail: widget.userEmail,
            ),
            BestRouteScreen(userEmail: widget.userEmail),
          ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 36,
            ),
            const SizedBox(width: 12),
            Text(widget.isAdmin ? 'Espace Administrateur' : 'Espace User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF7AB828))),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().logout(); // Déconnexion
              Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => LoginScreen()));
            },
            icon: const Icon(Icons.logout)
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 8,
        child: TabBar(
          controller: _tabController,
          tabs: tabs,
          labelColor: Color(0xFF7AB828),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xFF7AB828),
        ),
      ),
    );
  }
}

// Page d'upload
class UploadPage extends StatelessWidget {
  final Function onUploadSuccess;
  
  const UploadPage({Key? key, required this.onUploadSuccess}) : super(key: key);
  
  Future<String> getBasicAuth() async {
    String username = 'Abm2025@gmail.com';
    String password = 'Abm2025@';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    return basicAuth;
  }
  
  Future<void> uploadCsv(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Important: récupérer les données du fichier directement
      );
      
      if (result != null && result.files.isNotEmpty) {
        // Afficher un indicateur de chargement
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import en cours...'), duration: Duration(seconds: 1)));
        
        // Récupérer les bytes du fichier (fonctionne sur web et natif)
        final bytes = result.files.first.bytes;
        final fileName = result.files.first.name;
        
        if (bytes == null) {
          print("Erreur: impossible de lire le contenu du fichier");
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: impossible de lire le contenu du fichier')));
          return;
        }
        
        // Créer une requête multipart
        var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/upload-csv/'));
        request.headers['Authorization'] = await getBasicAuth();
        
        // Ajouter le fichier comme bytes
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));
        
        try {
          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);
          
          if (response.statusCode == 200) {
            print("Import réussi, redirection...");
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fichier importé avec succès'), duration: Duration(seconds: 1)));
            
            // Appeler la fonction de callback pour rediriger vers la liste
            onUploadSuccess();
          } else {
            print("Erreur lors de l'import: ${response.statusCode} - ${response.body}");
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur lors de l\'import du fichier: ${response.body}')));
          }
        } catch (e) {
          print("Erreur de connexion: $e");
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur de connexion: $e')));
        }
      }
    } catch (e) {
      print("Erreur lors de la sélection du fichier: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection du fichier: $e')));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Importer une liste de clients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ajoutez un fichier CSV contenant les informations des clients.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => uploadCsv(context),
              child: const Text('Importer un fichier CSV'),
            ),
          ],
        ),
      ),
    );
  }
}

// Page de liste des imports
class ImportsListPage extends StatefulWidget {
  final Function(Set<int>) onContinue;

  const ImportsListPage({Key? key, required this.onContinue}) : super(key: key);
  
  @override
  _ImportsListPageState createState() => _ImportsListPageState();
}

class _ImportsListPageState extends State<ImportsListPage> {
  List<dynamic> imports = [];
  bool loading = false;
  Set<int> selectedImports = {};  // Pour stocker les IDs des fichiers sélectionnés
  
  @override
  void initState() {
    super.initState();
    fetchImports();
  }
  
  Future<String> getBasicAuth() async {
    String username = 'Abm2025@gmail.com';
    String password = 'Abm2025@';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    return basicAuth;
  }
  
  Future<void> fetchImports() async {
    if (!mounted) return;
    
    print("Récupération des imports...");
    setState(() {
      loading = true;
    });
    
    try {
      final headers = {
        'Authorization': await getBasicAuth(),
      };
      final response = await http.get(Uri.parse('$backendUrl/imports/'), headers: headers);
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final importsList = jsonDecode(response.body);
        print("Imports récupérés: ${importsList.length}");
        setState(() {
          imports = importsList;
          loading = false;
        });
      } else {
        print("Erreur lors du chargement des imports: ${response.statusCode}");
        setState(() {
          loading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur lors du chargement des imports: ${response.statusCode}')));
        }
      }
    } catch (e) {
      print("Erreur de connexion: $e");
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de connexion: $e')));
    }
  }
  
  Future<void> deleteImport(int id) async {
    final headers = {
      'Authorization': await getBasicAuth(),
    };
    final response = await http.delete(Uri.parse('$backendUrl/imports/$id'), headers: headers);
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import supprimé')));
      fetchImports();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur suppression')));
    }
  }
  
  // Fonction pour calculer le total des clients sélectionnés
  int getSelectedClientsCount() {
    return imports
        .where((item) => selectedImports.contains(item['id']))
        .fold<int>(0, (sum, item) => sum + (item['client_count'] as int));
  }

  // Fonction pour gérer la sélection/désélection
  void toggleSelection(int id) {
    setState(() {
      if (selectedImports.contains(id)) {
        selectedImports.remove(id);
      } else {
        selectedImports.add(id);
      }
    });
  }

  // Fonction pour sélectionner/désélectionner tous les fichiers
  void toggleSelectAll() {
    setState(() {
      if (selectedImports.length == imports.length) {
        selectedImports.clear();
      } else {
        selectedImports = Set.from(imports.map((item) => item['id']));
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final int totalClients = selectedImports.isEmpty ? 0 : getSelectedClientsCount();

    return Container(
      color: const Color(0xFFF7F8FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Listes importées',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Sélectionnez une ou plusieurs listes à utiliser pour le calcul.',
              style: TextStyle(fontSize: 15, color: Color(0xFF7B7B7B)),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    text: 'Clients sélectionnés : ',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF7B7B7B)),
                    children: [
                      TextSpan(
                        text: '$totalClients clients',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDED),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, color: Color(0xFF7B7B7B)),
                    onPressed: () {},
                    tooltip: 'Filtrer',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : imports.isEmpty
                    ? const Center(child: Text('Aucun fichier importé'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: imports.length,
                        separatorBuilder: (context, index) => Divider(
                          color: const Color(0xFFEDEDED),
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final item = imports[index];
                          final isSelected = selectedImports.contains(item['id']);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (_) => toggleSelection(item['id']),
                              activeColor: Color(0xFF7AB828),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            title: Text(
                              item['filename'],
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['import_date']}', style: const TextStyle(color: Color(0xFF7B7B7B), fontSize: 13)),
                                Text('Nombre clients : ${item['client_count']}', style: const TextStyle(color: Color(0xFF7B7B7B), fontSize: 13)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFB0B0B0)),
                              onPressed: () => deleteImport(item['id']),
                              tooltip: 'Supprimer',
                            ),
                            selected: isSelected,
                            selectedTileColor: const Color(0xFF7AB828).withOpacity(0.06),
                            hoverColor: const Color(0xFF7AB828).withOpacity(0.06),
                          );
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: selectedImports.isEmpty ? null : () {
                  widget.onContinue(selectedImports);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7AB828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  elevation: 0,
                ),
                child: const Text('Continuer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Nouvelle page de calcul
class CalculePage extends StatefulWidget {
  final Set<int> selectedImportIds;
  final Function(int) onVendeursCalculated;

  const CalculePage({
    Key? key,
    required this.selectedImportIds,
    required this.onVendeursCalculated,
  }) : super(key: key);

  @override
  _CalculePageState createState() => _CalculePageState();
}

class _CalculePageState extends State<CalculePage> {
  int totalClients = 0;
  final TextEditingController clientsParJourController = TextEditingController();
  final TextEditingController joursDeTravailController = TextEditingController();

  // Variables d'état pour les résultats du calcul
  int capaciteParVendeur = 0;
  double vendeursNecessaires = 0.0;

  @override
  void initState() {
    super.initState();
    fetchTotalClients();
  }

  @override
  void didUpdateWidget(covariant CalculePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Vérifier si les IDs des imports sélectionnés ont changé
    if (widget.selectedImportIds != oldWidget.selectedImportIds) {
      fetchTotalClients(); // Rafraîchir le total si la sélection a changé
      // Réinitialiser les résultats du calcul si la selection change
      setState(() {
        capaciteParVendeur = 0;
        vendeursNecessaires = 0.0;
        clientsParJourController.clear();
        joursDeTravailController.clear();
      });
    }
  }

  @override
  void dispose() {
    clientsParJourController.dispose();
    joursDeTravailController.dispose();
    super.dispose();
  }

  Future<String> getBasicAuth() async {
    String username = 'Abm2025@gmail.com';
    String password = 'Abm2025@';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    return basicAuth;
  }

  Future<void> fetchTotalClients() async {
    if (widget.selectedImportIds.isEmpty) {
      setState(() {
        totalClients = 0;
      });
      return;
    }
    try {
      final headers = {
        'Authorization': await getBasicAuth(),
        'Content-Type': 'application/json',
      };
      final response = await http.post(
        Uri.parse('$backendUrl/total-clients/'),
        headers: headers,
        body: jsonEncode(widget.selectedImportIds.toList()),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalClients = data['total_clients'];
        });
      } else {
        print("Erreur lors du chargement du total clients: ${response.statusCode}");
        // Afficher un message d'erreur à l'utilisateur si nécessaire
      }
    } catch (e) {
      print("Erreur de connexion pour le total clients: $e");
      // Afficher un message d'erreur à l'utilisateur si nécessaire
    }
  }

  void _calculate() {
    // Récupérer les valeurs des champs de texte
    final clientsParJourText = clientsParJourController.text;
    final joursDeTravailText = joursDeTravailController.text;

    try {
      // Convertir les valeurs en nombres entiers
      final clientsParJour = int.parse(clientsParJourText);
      final joursDeTravail = int.parse(joursDeTravailText);

      // Vérifier que les valeurs sont positives
      if (clientsParJour <= 0 || joursDeTravail <= 0) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Veuillez entrer des nombres positifs pour les champs de saisie.')));
        return;
      }

      // Calculer la capacité par vendeur
      final calculatedCapacite = clientsParJour * joursDeTravail;

      // Calculer les vendeurs nécessaires (utiliser des doubles pour la division)
      double calculatedVendeurs = 0.0;
      if (calculatedCapacite > 0) {
        calculatedVendeurs = totalClients / calculatedCapacite;
        
        // Si le nombre de vendeurs nécessaires est dans l'intervalle [0;1], on l'arrondit à 1
        if (calculatedVendeurs > 0 && calculatedVendeurs <= 1) {
          calculatedVendeurs = 1.0;
        }
      }

      // Mettre à jour l'état avec les résultats
      setState(() {
        capaciteParVendeur = calculatedCapacite;
        vendeursNecessaires = calculatedVendeurs;
      });

      // Notifier le parent du nombre de vendeurs calculé
      widget.onVendeursCalculated(vendeursNecessaires.round());

    } catch (e) {
      // Gérer les erreurs de conversion si l'utilisateur n'entre pas des nombres
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez entrer des nombres valides dans les champs de saisie.')));
       setState(() {
          capaciteParVendeur = 0;
          vendeursNecessaires = 0.0;
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Titre et description
            const Text(
              'Répartition des visites',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Définissez vos paramètres pour organiser les visites de vos vendeurs.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Informations sur les clients
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.green, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations sur les clients',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nombre total de clients importés: $totalClients clients',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Clients à visiter par jour et par vendeur
            Text(
              'Clients à visiter par jour et par vendeur :',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: clientsParJourController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Entrez le nombre de clients par jour',
              ),
            ),
            const SizedBox(height: 16),

            // Nombre de jours de travail
            Text(
              'Nombre de jours de travail:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: joursDeTravailController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Entrez le nombre de jours de travail',
              ),
            ),
            const SizedBox(height: 24),

            // Bouton Calculer
            ElevatedButton(
              onPressed: _calculate, // Appeler la fonction de calcul
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Calculer'),
            ),
            const SizedBox(height: 24),

            // Résultat du calcul (placeholders)
            const Text(
              'Résultat du calcul:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capacité par Vendeur',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${capaciteParVendeur}', // Afficher le résultat calculé
                          style: TextStyle(fontSize: 24, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vendeurs Nécessaires',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${vendeursNecessaires.round()}', // Afficher le résultat calculé (arrondi à l'entier le plus proche)
                          style: const TextStyle(fontSize: 24, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bouton Afficher la carte
            ElevatedButton(
              onPressed: () {
                // Naviguer vers l'onglet "Carte" et passer le nombre de vendeurs nécessaires
                final mainTabsState = context.findAncestorStateOfType<_MainTabsPageState>();
                if (mainTabsState != null) {
                  // Mettre à jour le nombre de zones dans MapPage
                  final mapPageState = mainTabsState._mapPageKey.currentState;
                  if (mapPageState != null) {
                    mapPageState.initializeZones(vendeursNecessaires.round());
                  }
                  mainTabsState._tabController.animateTo(3); // 3 est l'index de l'onglet Carte
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Afficher la carte'),
            ),
          ],
        ),
      ),
    );
  }
}

// Classe pour gérer le clustering K-means
class KMeansClustering {
  final List<Map<String, dynamic>> points;
  final int k;
  List<Map<String, dynamic>> centroids = [];
  List<List<Map<String, dynamic>>> clusters = [];

  KMeansClustering(this.points, this.k);

  // Initialiser les centroïdes aléatoirement
  void _initializeCentroids() {
    final random = Random();
    final List<Map<String, dynamic>> shuffledPoints = List.from(points);
    shuffledPoints.shuffle(random);
    centroids = shuffledPoints.take(k).toList();
  }

  // Calculer la distance euclidienne entre deux points
  double _calculateDistance(Map<String, dynamic> point1, Map<String, dynamic> point2) {
    final lat1 = point1['latitude'] as double;
    final lon1 = point1['longitude'] as double;
    final lat2 = point2['latitude'] as double;
    final lon2 = point2['longitude'] as double;
    
    return sqrt(pow(lat2 - lat1, 2) + pow(lon2 - lon1, 2));
  }

  // Assigner chaque point au centroïde le plus proche
  void _assignPointsToClusters() {
    clusters = List.generate(k, (_) => []);
    
    for (var point in points) {
      double minDistance = double.infinity;
      int nearestCentroidIndex = 0;
      
      for (int i = 0; i < k; i++) {
        double distance = _calculateDistance(point, centroids[i]);
        if (distance < minDistance) {
          minDistance = distance;
          nearestCentroidIndex = i;
        }
      }
      
      clusters[nearestCentroidIndex].add(point);
    }
  }

  // Mettre à jour les centroïdes
  void _updateCentroids() {
    for (int i = 0; i < k; i++) {
      if (clusters[i].isEmpty) continue;
      
      double sumLat = 0;
      double sumLon = 0;
      
      for (var point in clusters[i]) {
        sumLat += point['latitude'] as double;
        sumLon += point['longitude'] as double;
      }
      
      centroids[i] = {
        'latitude': sumLat / clusters[i].length,
        'longitude': sumLon / clusters[i].length,
        'cluster_id': i,
      };
    }
  }

  // Exécuter l'algorithme K-means
  List<List<Map<String, dynamic>>> cluster() {
    _initializeCentroids();
    List<List<Map<String, dynamic>>> previousClusters;
    int iterations = 0;
    const maxIterations = 100;

    do {
      previousClusters = List.from(clusters);
      _assignPointsToClusters();
      _updateCentroids();
      iterations++;
    } while (!_areClustersEqual(previousClusters, clusters) && iterations < maxIterations);

    return clusters;
  }

  // Vérifier si les clusters sont égaux
  bool _areClustersEqual(List<List<Map<String, dynamic>>> clusters1, List<List<Map<String, dynamic>>> clusters2) {
    if (clusters1.length != clusters2.length) return false;
    
    for (int i = 0; i < clusters1.length; i++) {
      if (clusters1[i].length != clusters2[i].length) return false;
      
      for (int j = 0; j < clusters1[i].length; j++) {
        if (clusters1[i][j]['id'] != clusters2[i][j]['id']) return false;
      }
    }
    
    return true;
  }
}

// Classe pour calculer l'enveloppe convexe (convex hull)
class ConvexHull {
  static List<Map<String, dynamic>> compute(List<Map<String, dynamic>> points) {
    if (points.length < 3) return points;

    // Trier les points par coordonnées
    points.sort((a, b) {
      if (a['latitude'] != b['latitude']) {
        return a['latitude'].compareTo(b['latitude']);
      }
      return a['longitude'].compareTo(b['longitude']);
    });

    List<Map<String, dynamic>> lower = [];
    List<Map<String, dynamic>> upper = [];

    // Construire l'enveloppe convexe inférieure
    for (var point in points) {
      while (lower.length >= 2 && !_isRightTurn(lower[lower.length - 2], lower[lower.length - 1], point)) {
        lower.removeLast();
      }
      lower.add(point);
    }

    // Construire l'enveloppe convexe supérieure
    for (var point in points.reversed) {
      while (upper.length >= 2 && !_isRightTurn(upper[upper.length - 2], upper[upper.length - 1], point)) {
        upper.removeLast();
      }
      upper.add(point);
    }

    // Combiner les deux enveloppes
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  static bool _isRightTurn(Map<String, dynamic> a, Map<String, dynamic> b, Map<String, dynamic> c) {
    return ((b['longitude'] - a['longitude']) * (c['latitude'] - a['latitude']) -
            (b['latitude'] - a['latitude']) * (c['longitude'] - a['longitude'])) > 0;
  }
}

// Page de carte
class MapPage extends StatefulWidget {
  final Set<int> selectedImportIds;
  final int initialNombreZones;
  final bool isAdmin;
  final String userEmail;

  const MapPage({
    Key? key,
    required this.selectedImportIds,
    required this.initialNombreZones,
    required this.isAdmin,
    required this.userEmail,
  }) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController nombreZonesController = TextEditingController();
  final String tomtomApiKey = 'De8uDhsXRucjZ9ERWjV7PVGf6H3cApG8';
  List<Map<String, dynamic>> clientsCoordinates = [];
  bool loading = true;
  String errorMessage = '';
  int nombreZones = 0;
  List<List<Map<String, dynamic>>> clusters = [];
  List<Map<String, dynamic>> centroids = [];
  Map<int, List<LatLng>> optimizedRoutes = {};
  bool isDragging = false;
  Map<String, dynamic>? draggedClient;
  int? draggedClientZone;
  bool _isPanelVisible = true;
  bool _isInitialized = false;
  bool _isCalculatingRoutes = false;
  
  final MapController mapController = MapController();

  Map<int, String?> _selectedUsersForZones = {};
  List<dynamic> _users = [];
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;

    setState(() {
      _isInitialized = true; // Marquer comme initialisé tôt
      loading = true; // Afficher le spinner de chargement
      errorMessage = ''; // Effacer les erreurs précédentes
    });
    
    // Maintenant, effectuer les opérations asynchrones
    await fetchClientsCoordinates();
    await _fetchUsers();
    
    if (widget.initialNombreZones > 0 && widget.isAdmin) {
      nombreZonesController.text = widget.initialNombreZones.toString();
      await _validerNombreZones();
    }
    
    // Mise à jour finale de l'état une fois toutes les opérations asynchrones terminées
    if (mounted) {
      setState(() {
        loading = false; // Désactiver le chargement lorsque tout est terminé
      });
    }
  }
  
  @override
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNombreZones != oldWidget.initialNombreZones && 
        widget.initialNombreZones > 0 && 
        !_isInitialized &&
        widget.isAdmin) {
      nombreZonesController.text = widget.initialNombreZones.toString();
      _validerNombreZones();
    }
    if (widget.userEmail != oldWidget.userEmail && !widget.isAdmin) {
      // Si l'email de l'utilisateur change et n'est pas administrateur, rafraîchir les coordonnées
      // Réinitialiser _isInitialized pour forcer un rechargement complet via _initializeData
      setState(() {
        _isInitialized = false;
      });
      _initializeData();
    }
  }

  Future<void> _validerNombreZones() async {
    if (loading || _isCalculatingRoutes) return;
    
    try {
      final nombre = int.parse(nombreZonesController.text);
      if (nombre <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le nombre de zones doit être positif')),
        );
        return;
      }
      if (nombre > clientsCoordinates.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le nombre de zones ne peut pas être supérieur au nombre de clients')),
        );
        return;
      }
      
      setState(() {
        nombreZones = nombre;
        loading = true;
        _isCalculatingRoutes = true;
        optimizedRoutes.clear();
        _selectedUsersForZones = Map.fromIterable(
          List.generate(nombre, (i) => i),
          key: (i) => i,
          value: (i) => _selectedUsersForZones.containsKey(i) ? _selectedUsersForZones[i] : null
        );
      });

      final List<Map<String, dynamic>> points = clientsCoordinates
          .map((point) => Map<String, dynamic>.from(point))
          .toList();

      final kmeans = KMeansClustering(points, nombre);
      final newClusters = kmeans.cluster();
      
      if (mounted) {
        setState(() {
          clusters = newClusters;
          centroids = kmeans.centroids;
        });
      }

      await calculateAllOptimizedRoutes();

      if (mounted) {
        setState(() {
          loading = false;
          _isCalculatingRoutes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nombre de zones défini : $nombre')),
        );
      }
    } catch (e) {
      print('Erreur lors de la validation du nombre de zones: $e');
      if (mounted) {
        setState(() {
          loading = false;
          _isCalculatingRoutes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer un nombre valide')),
        );
      }
    }
  }

  Future<void> calculateAllOptimizedRoutes() async {
    if (!mounted || _isCalculatingRoutes) return;
    
    setState(() {
      _isCalculatingRoutes = true;
      optimizedRoutes.clear();
    });

    for (int i = 0; i < clusters.length; i++) {
      if (!mounted) return;
      await calculateOptimizedRoute(i);
    }

    if (mounted) {
      setState(() {
        _isCalculatingRoutes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFF7AB828)),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              if (widget.selectedImportIds.isEmpty && widget.isAdmin) // Afficher seulement pour l'admin
                ElevatedButton(
                  onPressed: () {
                    final mainTabsState = context.findAncestorStateOfType<_MainTabsPageState>();
                    if (mainTabsState != null) {
                      mainTabsState._tabController.animateTo(1);
                    }
                  },
                  child: const Text('Sélectionner des fichiers'),
                ),
            ],
          ),
        ),
      );
    }
    
    if (clientsCoordinates.isEmpty) {
      return const Center(
        child: Text('Aucune coordonnée de client trouvée dans les fichiers sélectionnés.'),
      );
    }
    
    // Calculer le centre et le zoom de la carte
    final center = _calculateMapCenter();
    final zoom = _calculateZoomLevel();
    
    return Scaffold(
      body: Row(
        children: [
          // Panneau latéral gauche pour les contrôles
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isPanelVisible && widget.isAdmin ? 300 : 0, // Visible et largeur réduite si non-admin
            color: Colors.grey[100],
            child: _isPanelVisible && widget.isAdmin ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Carte des clients',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _isPanelVisible = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${clientsCoordinates.length} clients affichés',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuration des zones',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nombreZonesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de zones',
                              border: OutlineInputBorder(),
                              hintText: 'Entrez le nombre de zones',
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _validerNombreZones,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Valider'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (nombreZones > 0) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Légende des zones',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ...List<Widget>.generate(clusters.length, (index) {
                              final color = _getZoneColor(index);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Zone ${index + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButton<String>(
                                      value: _selectedUsersForZones[index],
                                      hint: const Text('Sélectionner un vendeur'),
                                      isExpanded: true,
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedUsersForZones[index] = newValue;
                                        });
                                      },
                                      items: _users.map<DropdownMenuItem<String>>((user) {
                                        return DropdownMenuItem<String>(
                                          value: user['email'],
                                          child: Text(
                                            user['email'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _validerZoneSelection(index),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Valider'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Ajouter le bouton de suppression en bas du panneau
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gestion des zones',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _confirmAndDeleteAllZones(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Supprimer toutes les zones'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ) : null,
          ),
          // Carte principale
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    center: center,
                    zoom: zoom,
                    maxZoom: 18.0,
                    minZoom: 3.0,
                    onMapReady: () {
                      if (widget.initialNombreZones > 0 && clientsCoordinates.isNotEmpty && widget.isAdmin) {
                        _validerNombreZones();
                      } else if (!widget.isAdmin) {
                        // Pour les non-admins, forcer le rafraîchissement avec l'email de l'utilisateur
                        fetchClientsCoordinates();
                      }
                    },
                    onTap: (tapPosition, latLng) {
                      if (isDragging) {
                        final newZoneId = findNearestZone(latLng);
                        if (newZoneId != -1 && draggedClient != null) {
                          moveClientToZone(draggedClient!, newZoneId);
                        }
                        setState(() {
                          isDragging = false;
                          draggedClient = null;
                          draggedClientZone = null;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.abm_sales',
                      tileProvider: NetworkTileProvider(),
                      tileBuilder: (context, tileWidget, tile) {
                        return tileWidget;
                      },
                    ),
                    PolylineLayer(
                      polylines: optimizedRoutes.entries.map((entry) {
                        return Polyline(
                          points: entry.value,
                          strokeWidth: 4.0,
                          color: _getZoneColor(entry.key),
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers: [
                        ...clientsCoordinates.map((client) {
                          final clientLatLng = LatLng(client['latitude'], client['longitude']);
                          int zoneIndex = -1;
                          for (int i = 0; i < clusters.length; i++) {
                            if (clusters[i].any((c) => c['id'] == client['id'])) {
                              zoneIndex = i;
                              break;
                            }
                          }
                          final Color markerColor = zoneIndex != -1 ? _getZoneColor(zoneIndex) : const Color(0xFFE53935);

                          return Marker(
                            width: 40.0,
                            height: 40.0,
                            point: clientLatLng,
                            child: GestureDetector(
                              onLongPressStart: (details) {
                                if (widget.isAdmin) { // Permettre le drag uniquement pour l'admin
                                  setState(() {
                                    isDragging = true;
                                    draggedClient = client;
                                    draggedClientZone = zoneIndex;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Glissez le client ${client['nom']} pour le déplacer')),
                                  );
                                }
                              },
                              child: Icon(
                                Icons.location_pin,
                                color: markerColor,
                                size: 40.0,
                              ),
                            ),
                          );
                        }).toList(),
                        if (widget.isAdmin) // Afficher les centroïdes uniquement pour l'admin
                          ...centroids.map((centroid) {
                            return Marker(
                              width: 50.0,
                              height: 50.0,
                              point: LatLng(centroid['latitude'], centroid['longitude']),
                              child: const Icon(
                                Icons.star,
                                color: Colors.black,
                                size: 30.0,
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ],
                ),
                if (!_isPanelVisible && widget.isAdmin) // Afficher le bouton du panneau seulement si admin
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Card(
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _isPanelVisible = true;
                          });
                        },
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Card(
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            mapController.move(
                              mapController.center,
                              mapController.zoom + 1,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            mapController.move(
                              mapController.center,
                              mapController.zoom - 1,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.center_focus_strong),
                          onPressed: () {
                            mapController.move(center, zoom);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (isDragging && widget.isAdmin) // Afficher l'indicateur de glissement uniquement pour l'admin
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Déplacer ${draggedClient!['nom']} (Zone ${draggedClientZone! + 1})',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to get color for a zone
  Color _getZoneColor(int index) {
    final List<Color> colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.cyan,
      Colors.indigo,
      Colors.lime,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  Future<void> fetchClientsCoordinates() async {
    if (!widget.isAdmin && widget.userEmail.isEmpty) {
      setState(() {
        clientsCoordinates = [];
        loading = false;
        errorMessage = 'Email utilisateur non disponible.';
      });
      return;
    }

    try {
      final headers = {
        'Authorization': await getBasicAuth(),
        'Content-Type': 'application/json',
      };

      http.Response response;

      if (widget.isAdmin) {
        if (widget.selectedImportIds.isEmpty) {
          setState(() {
            clientsCoordinates = [];
            loading = false;
            errorMessage = 'Aucun fichier sélectionné. Veuillez sélectionner des fichiers dans la page "Listes de fichiers".';
          });
          return;
        }
        response = await http.post(
          Uri.parse('$backendUrl/clients-coordinates/'),
          headers: headers,
          body: jsonEncode(widget.selectedImportIds.toList()),
        );
      } else {
        response = await http.get(
          Uri.parse('$backendUrl/zones/user/${widget.userEmail}'),
          headers: headers,
        );
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (!widget.isAdmin) {
            clientsCoordinates = [];
            for (var zone in data) {
              clientsCoordinates.add({
                "id": zone['id'],
                "nom": "Client de Zone ${zone['name'].split(' ').last}",
                "prenom": "",
                "latitude": zone['latitude'],
                "longitude": zone['longitude'],
              });
            }
          } else {
            clientsCoordinates = List<Map<String, dynamic>>.from(data['coordinates']);
          }
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = 'Erreur lors de la récupération des coordonnées: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Erreur de connexion: $e';
      });
    }
  }
  
  // Calculer le centre de la carte et le niveau de zoom approprié
  LatLng _calculateMapCenter() {
    if (clientsCoordinates.isEmpty) {
      // Coordonnées par défaut (Maroc)
      return LatLng(31.7917, -7.0926);
    }
    
    double sumLat = 0;
    double sumLng = 0;
    for (var client in clientsCoordinates) {
      sumLat += client['latitude'];
      sumLng += client['longitude'];
    }
    
    // Ajouter une marge pour un meilleur centrage
    final centerLat = sumLat / clientsCoordinates.length;
    final centerLng = sumLng / clientsCoordinates.length;
    
    return LatLng(centerLat, centerLng);
  }
  
  // Déterminer le niveau de zoom approprié
  double _calculateZoomLevel() {
    if (clientsCoordinates.length <= 1) return 13.0;
    
    // Trouver les limites min/max pour déterminer l'étendue
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (var client in clientsCoordinates) {
      final lat = client['latitude'];
      final lng = client['longitude'];
      
      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }
    
    // Calculer l'étendue
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    
    // Ajuster le zoom en fonction de l'étendue avec des valeurs plus appropriées
    if (latDiff > 2.0 || lngDiff > 2.0) return 6.0;
    if (latDiff > 1.0 || lngDiff > 1.0) return 7.0;
    if (latDiff > 0.5 || lngDiff > 0.5) return 8.0;
    if (latDiff > 0.2 || lngDiff > 0.2) return 9.0;
    if (latDiff > 0.1 || lngDiff > 0.1) return 10.0;
    if (latDiff > 0.05 || lngDiff > 0.05) return 11.0;
    if (latDiff > 0.02 || lngDiff > 0.02) return 12.0;
    
    return 13.0;
  }
  
  // Fonction pour calculer la route optimisée pour une zone
  Future<void> calculateOptimizedRoute(int zoneId) async {
    if (clusters.isEmpty || zoneId >= clusters.length) return;

    final points = clusters[zoneId];
    if (points.length < 2) return;

    try {
      print('Calcul de la route pour la zone $zoneId avec ${points.length} points');
      
      // Convertir les points en format pour l'API TomTom
      final List<Map<String, dynamic>> routePoints = points.map((point) => {
        'lat': point['latitude'],
        'lon': point['longitude']
      }).toList();

      // Construire l'URL pour l'API de routage TomTom avec les paramètres corrigés
      final queryParams = {
        'key': tomtomApiKey,
        'traffic': 'true',
        'travelMode': 'car',
        'routeType': 'fastest',
        'departAt': DateTime.now().toUtc().toIso8601String(),
        'computeBestOrder': 'true',
        'routeRepresentation': 'polyline',
        'instructionsType': 'text',
        'language': 'fr-FR',
      };

      // Construire la chaîne de points pour l'URL
      final pointsString = routePoints.map((p) => "${p['lat']},${p['lon']}").join(':');
      final url = Uri.https('api.tomtom.com', '/routing/1/calculateRoute/$pointsString/json', queryParams);

      print('Appel de l\'API TomTom avec l\'URL: $url');

      final response = await http.get(url);
      print('Réponse de l\'API TomTom: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Données reçues de l\'API: ${data.keys.toList()}');
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final List<LatLng> routePoints = [];

          // Extraire les points de la route
          if (route['legs'] != null) {
            for (var leg in route['legs']) {
              if (leg['points'] != null) {
                for (var point in leg['points']) {
                  routePoints.add(LatLng(point['latitude'], point['longitude']));
                }
              }
            }
          }

          print('Route calculée avec ${routePoints.length} points');

          if (mounted) {
            setState(() {
              optimizedRoutes[zoneId] = routePoints;
            });
          }
        } else {
          print('Aucune route trouvée dans la réponse');
        }
      } else {
        print('Erreur API: ${response.body}');
      }
    } catch (e) {
      print('Erreur lors du calcul de la route optimisée: $e');
    }
  }

  // Fonction pour déplacer un client vers une nouvelle zone
  void moveClientToZone(Map<String, dynamic> client, int newZoneId) async {
    if (newZoneId < 0 || newZoneId >= clusters.length) return;

    setState(() {
      loading = true;
    });

    try {
      List<List<Map<String, dynamic>>> newClusters = List.generate(clusters.length, (index) => []);
      
      for (int i = 0; i < clusters.length; i++) {
        for (var c in clusters[i]) {
          if (c['id'] == client['id']) {
            newClusters[newZoneId].add(c);
          } else {
            newClusters[i].add(c);
          }
        }
      }

      setState(() {
        clusters = newClusters;
      });

      await calculateAllOptimizedRoutes();

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client déplacé vers le vendeur ${newZoneId + 1}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Erreur lors du déplacement du client: $e');
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du déplacement du client: $e')),
      );
    }
  }

  // Fonction pour déterminer la zone la plus proche d'un point
  int findNearestZone(LatLng point) {
    if (clusters.isEmpty) return -1;

    double minDistance = double.infinity;
    int nearestZone = 0;

    for (int i = 0; i < clusters.length; i++) {
      double sumLat = 0;
      double sumLng = 0;
      for (var client in clusters[i]) {
        sumLat += client['latitude'];
        sumLng += client['longitude'];
      }
      double centerLat = sumLat / clusters[i].length;
      double centerLng = sumLng / clusters[i].length;

      double distance = sqrt(
        pow(point.latitude - centerLat, 2) + 
        pow(point.longitude - centerLng, 2)
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestZone = i;
      }
    }

    return nearestZone;
  }

  Future<Map<String, dynamic>> _getRouteInfo(int zoneId) async {
    try {
      final points = clusters[zoneId];
      if (points.isEmpty) return {};

      final pointsStr = points.map((point) => 
        '${point['latitude']},${point['longitude']}').join(':');
      
      final url = Uri.parse(
        'https://api.tomtom.com/routing/1/calculateRoute/$pointsStr/json'
        '?key=$tomtomApiKey'
        '&traffic=true'
        '&travelMode=car'
        '&computeBestOrder=true'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          return {
            'distance': (route['summary']['lengthInMeters'] / 1000).toStringAsFixed(1),
            'duration': _formatDuration(route['summary']['travelTimeInSeconds']),
          };
        }
      }
      return {};
    } catch (e) {
      print('Erreur lors de la récupération des informations de route: $e');
      return {};
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  Future<void> _fetchUsers() async {
    if (!widget.isAdmin) return; // Seuls les admins ont besoin de la liste des utilisateurs pour assigner
    try {
      final headers = {
        'Authorization': await getBasicAuth(),
      };

      final response = await http.get(
        Uri.parse('$backendUrl/admin/users/'),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          for (int i = 0; i < nombreZones; i++) {
            if (!_selectedUsersForZones.containsKey(i)) {
              _selectedUsersForZones[i] = null;
            }
          }
        });
      } else {
        print('Erreur lors de la récupération des utilisateurs: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la récupération des utilisateurs: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Erreur de connexion lors de la récupération des utilisateurs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion lors de la récupération des utilisateurs: $e')),
      );
    }
  }

  Future<String> getBasicAuth() async {
    String username = 'Abm2025@gmail.com';
    String password = 'Abm2025@';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    return basicAuth;
  }

  void initializeZones(int numberOfZones) {
    if (numberOfZones > 0) {
      nombreZonesController.text = numberOfZones.toString();
      _validerNombreZones();
    }
  }

  void _validerZoneSelection(int zoneIndex) async {
    final selectedUserEmail = _selectedUsersForZones[zoneIndex];

    if (selectedUserEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un vendeur pour cette zone.')),
      );
      return;
    }

    if (zoneIndex >= clusters.length || clusters[zoneIndex].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun client dans la Zone ${zoneIndex + 1} pour enregistrement.')),
      );
      return;
    }

    final List<Map<String, dynamic>> clientsInZone = clusters[zoneIndex];
    final List<Map<String, dynamic>> zonesToSave = [];

    for (var client in clientsInZone) {
      zonesToSave.add({
        'name': 'Zone ${zoneIndex + 1}',
        'email': selectedUserEmail,
        'longitude': client['longitude'],
        'latitude': client['latitude'],
      });
    }

    try {
      final headers = {
        'Authorization': await getBasicAuth(),
        'Content-Type': 'application/json',
      };

      final response = await http.post(
        Uri.parse('$backendUrl/zones/'),
        headers: headers,
        body: jsonEncode(zonesToSave),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zone ${zoneIndex + 1} validée et clients enregistrés avec succès.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement des clients pour la Zone ${zoneIndex + 1}: ${response.statusCode} - ${response.body}')),
        );
        print('Erreur API Zones: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion lors de l\'enregistrement des clients pour la Zone ${zoneIndex + 1}: $e')),
      );
      print('Erreur de connexion Zones: $e');
    }
  }

  Future<void> _deleteAllZones() async {
    final String? token = await AuthService().getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Non authentifié.')));
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$backendUrl/zones/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toutes les zones ont été supprimées avec succès !'))
        );
        // Rafraîchir la carte après la suppression
        fetchClientsCoordinates();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec de la suppression des zones: ${response.statusCode}'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression des zones: $e'))
      );
    }
  }

  Future<void> _confirmAndDeleteAllZones(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer toutes les zones ? Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Annuler
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Confirmer
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteAllZones();
    }
  }
}
