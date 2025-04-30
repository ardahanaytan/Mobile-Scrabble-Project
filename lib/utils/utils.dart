import 'package:flutter/material.dart';
 
 void showSnackBar(BuildContext context, String text) {
   // Check if the context is still valid before showing the SnackBar
   if (context.mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(text),
       ),
     );
   } else {
     print("SnackBar Error: Context is no longer mounted. Message: $text");
   }
 }