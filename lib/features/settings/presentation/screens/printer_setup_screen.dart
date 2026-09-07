import 'package:flutter/material.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  // Mock list of printers for now since direct hardware access depends on plugins and permissions
  // In a real app, use blue_thermal_printer or printing package's scan methods
  List<Map<String, dynamic>> _devices = [];
  bool _isScanning = false;
  String? _selectedDeviceName;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);

    // Simulate finding devices
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isScanning = false;
        _devices = [
          {
            'name': 'POS-58 (Simulated)',
            'address': '00:11:22:33:44:55',
            'type': 'Bluetooth'
          },
          {
            'name': 'Epson TM-T88 (Simulated)',
            'address': '192.168.1.100',
            'type': 'WiFi'
          },
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Configuration'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScan,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select a printer to use for receipts.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? const Center(child: Text('No devices found'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isSelected = _selectedDeviceName == device['name'];

                      return ListTile(
                        leading: Icon(
                          device['type'] == 'Bluetooth'
                              ? Icons.bluetooth
                              : Icons.wifi,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        title: Text(device['name']),
                        subtitle: Text(device['address']),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedDeviceName = device['name'];
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Printer connected: ${device['name']}')),
                          );
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // Test Print
                if (_selectedDeviceName != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Printing Test Slip...')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please select a printer first')),
                  );
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Test Print'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          )
        ],
      ),
    );
  }
}
