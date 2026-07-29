import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProtocolFlowAppBar extends AppBar {
  ProtocolFlowAppBar({
    super.key,
    required String title,
    super.actions,
    super.leading,
    super.automaticallyImplyLeading = true,
    super.bottom,
  }) : super(
         toolbarHeight: 64,
         backgroundColor: AppColors.surface,
         foregroundColor: AppColors.textPrimary,
         surfaceTintColor: Colors.transparent,
         elevation: 0,
         scrolledUnderElevation: 1,
         centerTitle: false,
         title: Text(
           title,
           maxLines: 1,
           overflow: TextOverflow.ellipsis,
           style: const TextStyle(
             color: AppColors.primary,
             fontSize: 22,
             fontWeight: FontWeight.w700,
           ),
         ),
       );
}
