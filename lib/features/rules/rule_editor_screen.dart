import 'package:flutter/material.dart';

import 'package:otpbridge/domain/models/models.dart';

import 'new_rule_wizard.dart';
import 'rule_edit_form.dart';

/// Create or edit a [ForwardRule]. Pass null to create a new rule.
///
/// New rules go through the fast 4-step [NewRuleWizard] (category →
/// services → recipients → schedule); editing an existing rule opens the
/// compact [RuleEditForm].
class RuleEditorScreen extends StatelessWidget {
  const RuleEditorScreen({super.key, this.rule});

  final ForwardRule? rule;

  @override
  Widget build(BuildContext context) {
    final rule = this.rule;
    if (rule == null) return const NewRuleWizard();
    return RuleEditForm(rule: rule);
  }
}
