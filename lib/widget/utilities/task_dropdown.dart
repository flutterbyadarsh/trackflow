
import 'package:flutter/material.dart';
// used nhi hai eska kuch bhi delete kardo
class TaskDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?>onChanged;

  const TaskDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
});

  static const Color purple = Color(0xFF7C3AED);
  @override

  Widget build (BuildContext context) {
    return DropdownButtonFormField <String>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,

          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,

            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: purple,
              width: 1.5,

            ),
          ),
        ),

        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged
    );
     //User ke selection ko parent screen tak pahunchata hai,
    // jahan setState() selected value update karta hai.

  }
}