import 'package:flutter/material.dart';
import '../../models/gold_asset.dart';
import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../utils/date_formatters.dart';

class AppointmentPage extends StatefulWidget {
  final Appointment? editingAppointment;
  const AppointmentPage({super.key, this.editingAppointment});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final AppointmentService _service = AppointmentService();

  GoldAsset? _passedAsset;
  Appointment? _editingAppointment;
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<Appointment> _dailyBookings = [];
  bool _isLoadingSlots = false;
  bool _isProcessing = false;

  // Generate 30-min slots from 09:00 to 16:30
  final List<TimeOfDay> _allSlots = List.generate(16, (index) {
    int hour = 9 + (index ~/ 2);
    int minute = (index % 2) * 30;
    return TimeOfDay(hour: hour, minute: minute);
  });

  @override
  void initState() {
    super.initState();
    if (widget.editingAppointment != null) {
      _editingAppointment = widget.editingAppointment;
      _selectedDate = _editingAppointment!.date;
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate!);
      _fetchSlotsForDate(_selectedDate!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editingAppointment == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is GoldAsset) {
        _passedAsset = args;
      }
    }
  }

  Future<void> _fetchSlotsForDate(DateTime date) async {
    setState(() => _isLoadingSlots = true);
    try {
      final bookings = await _service.getAppointmentsForDate(date);
      if (mounted && _selectedDate == date) {
        setState(() {
          _dailyBookings = bookings;
          _isLoadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      selectableDayPredicate: (DateTime val) => val.weekday != DateTime.sunday,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time when date changes
      });
      _fetchSlotsForDate(picked);
    }
  }

  int _getSlotBookings(TimeOfDay slot) {
    if (_selectedDate == null) return 0;
    return _dailyBookings.where((apt) {
      // If we are editing, do NOT count our own appointment if it hits this exact slot naturally
      if (_editingAppointment != null && apt.id == _editingAppointment!.id) return false;
      return apt.date.hour == slot.hour && apt.date.minute == slot.minute;
    }).length;
  }

  Future<void> _confirmAppointment() async {
    if ((_passedAsset == null && _editingAppointment == null) || _selectedDate == null || _selectedTime == null) return;

    setState(() => _isProcessing = true);
    
    try {
      final combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (_editingAppointment != null) {
        await _service.updateAppointment(_editingAppointment!.id, combinedDateTime);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เลื่อนนัดหมายสำเร็จ!')));
          Navigator.pop(context); // Go back if we navigated here purely to edit
        }
      } else {
        await _service.createAppointment(
          asset: _passedAsset!,
          appointmentDate: combinedDateTime,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('นัดหมายสำเร็จ!')));
          setState(() {
            _passedAsset = null; // Clear booking form
            _selectedDate = null;
            _selectedTime = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showAppointmentOptions(Appointment apt) {
    if (apt.status != 'scheduled' || apt.date.isBefore(DateTime.now())) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('จัดการนัดหมาย', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(apt.assetName, style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: const Text('เลื่อนนัดหมาย'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppointmentPage(editingAppointment: apt)),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('ยกเลิกนัดหมาย', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                _promptCancel(apt);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _promptCancel(Appointment apt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกนัดหมาย?'),
        content: const Text('การยกเลิกนัดหมายจะยกเลิกช่วงเวลานี้ และสินค้าของคุณจะกลับไปอยู่ในพอร์ตโฟลิโอ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ไม่เก็บไว้ตามเดิม'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // close dialog
              try {
                await _service.cancelAppointment(apt.id, apt.assetId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยกเลิกนัดหมายแล้ว')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('ใช่, ยกเลิกเดี๋ยวนี้', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we passed an editing appointment explicitly, we might not even need tabs, 
    // but building inside the tab layout keeps the UI consistent.
    final hasAssetContext = _passedAsset != null || _editingAppointment != null;
    final isEditing = _editingAppointment != null;

    return DefaultTabController(
      initialIndex: hasAssetContext ? 0 : 1,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF800000),
          foregroundColor: Colors.white,
          title: Text(isEditing ? 'เลื่อนเวลารับสินค้า' : 'นัดรับสินค้าที่ร้าน'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: const Color(0xFFFFD700),
            tabs: [
              Tab(text: isEditing ? 'แก้ไขเวลา' : 'นัดรับสินค้า', icon: const Icon(Icons.add_shopping_cart)),
              const Tab(text: 'ตารางของฉัน', icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBookingTab(),
            _buildMyScheduleTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingTab() {
    if (_passedAsset == null && _editingAppointment == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'ยังไม่ได้เลือกสินค้า',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'กรุณาไปที่พอร์ตโฟลิโอของคุณและเลือก "รับสินค้าที่ร้าน" เพื่อทำการนัดหมาย',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final assetName = _editingAppointment?.assetName ?? _passedAsset!.name;
    final isEditing = _editingAppointment != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(isEditing ? 'กำลังแก้ไขรายการ' : 'สินค้าที่ต้องการรับ', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(assetName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF800000))),
                  if (!isEditing) Text('น้ำหนัก: ${_passedAsset!.weight} บาท', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('เลือกวันที่', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(_selectedDate == null ? 'แตะเพื่อเลือกวัน' : FormatterUtils.formatThaiDateShort(_selectedDate!)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          
          if (_selectedDate != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('เลือกเวลา', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isLoadingSlots) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isLoadingSlots)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _allSlots.length,
                itemBuilder: (context, index) {
                  final slot = _allSlots[index];
                  final bookingsCount = _getSlotBookings(slot);
                  final isFull = bookingsCount >= 2;
                  final isSelected = _selectedTime == slot;
                  
                  return InkWell(
                    onTap: isFull ? null : () => setState(() => _selectedTime = slot),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                           ? const Color(0xFF800000) 
                           : (isFull ? Colors.grey[200] : Colors.white),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF800000) : (isFull ? Colors.grey[300]! : Colors.grey),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slot.format(context), 
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isFull ? Colors.grey : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              decoration: isFull ? TextDecoration.lineThrough : null,
                            )
                          ),
                          if (isFull)
                            const Text('เต็ม', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: (_selectedDate != null && _selectedTime != null && !_isProcessing) ? _confirmAppointment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF800000),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: _isProcessing 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEditing ? 'ยืนยันการเลื่อนนัด' : 'ยืนยันการนัดรับสินค้า', style: const TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMyScheduleTab() {
    return StreamBuilder<List<Appointment>>(
      stream: _service.getAppointmentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('ข้อผิดพลาดการโหลดนัดหมาย: ${snapshot.error}'));
        }

        final appointments = snapshot.data ?? [];

        if (appointments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('ไม่มีนัดหมายเร็วๆ นี้', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final apt = appointments[index];
            final isCompleted = apt.status == 'completed';
            final color = isCompleted ? Colors.green : const Color(0xFF800000); // Brand primary color
            final icon = isCompleted ? Icons.check_circle : Icons.schedule;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _showAppointmentOptions(apt),
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color),
                ),
                title: Text(apt.assetName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(FormatterUtils.formatThaiDateTime(apt.date)),
                    Text(
                      isCompleted ? 'เสร็จสิ้น' : 'นัดหมายแล้ว (แตะเพื่อจัดการ)',
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
