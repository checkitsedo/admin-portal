import 'dart:async';
import 'package:invoiceninja_flutter/redux/app/app_actions.dart';
import 'package:flutter/material.dart';
import 'package:invoiceninja_flutter/utils/completers.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:invoiceninja_flutter/redux/transaction/transaction_actions.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/ui/transaction/view/transaction_view.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';

class TransactionViewScreen extends StatelessWidget {
  const TransactionViewScreen({
    Key key,
    this.isFilter = false,
  }) : super(key: key);
  static const String route = '/transaction/view';
  final bool isFilter;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, TransactionViewVM>(
      converter: (Store<AppState> store) {
        return TransactionViewVM.fromStore(store);
      },
      builder: (context, vm) {
        return TransactionView(
          viewModel: vm,
          isFilter: isFilter,
        );
      },
    );
  }
}

class TransactionViewVM {
  TransactionViewVM({
    @required this.state,
    @required this.transactions,
    @required this.company,
    @required this.onEntityAction,
    @required this.onRefreshed,
    @required this.isSaving,
    @required this.isLoading,
    @required this.onConvertToPayment,
    @required this.onConvertToExpense,
  });

  factory TransactionViewVM.fromStore(Store<AppState> store) {
    final state = store.state;
    final List<TransactionEntity> transactions = [];
    List<String> transactionIds = [];
    if (state.transactionListState.isInMultiselect()) {
      transactionIds = state.transactionListState.selectedIds.toList();
    } else {
      transactionIds = [state.transactionUIState.selectedId];
    }

    transactionIds.forEach((transactionId) {
      transactions.add(state.transactionState.map[transactionId] ??
          TransactionEntity(id: transactionId));
    });

    Future<Null> _handleRefresh(BuildContext context) {
      if (transactions.isEmpty) {
        return null;
      }
      final completer = snackBarCompleter<Null>(
          context, AppLocalization.of(context).refreshComplete);
      store.dispatch(LoadTransaction(
          completer: completer, transactionId: transactions.first.id));
      return completer.future;
    }

    return TransactionViewVM(
      state: state,
      company: state.company,
      isSaving: state.isSaving,
      isLoading: state.isLoading,
      transactions: transactions,
      onRefreshed: (context) => _handleRefresh(context),
      onEntityAction: (BuildContext context, EntityAction action) =>
          handleEntitiesActions(transactions, action, autoPop: true),
      onConvertToPayment: (context, invoiceIds) {
        store.dispatch(
          ConvertTransactionToPaymentRequest(
              snackBarCompleter<Null>(
                  context, AppLocalization.of(context).convertedTransaction),
              transactionIds.first,
              invoiceIds),
        );
      },
      onConvertToExpense: (context, vendorId, categoryId) {
        store.dispatch(
          ConvertTransactionsToExpensesRequest(
            snackBarCompleter<Null>(
                context, AppLocalization.of(context).convertedTransaction)
              ..future.then((value) {
                if (state.transactionListState.isInMultiselect()) {
                  store.dispatch(ClearTransactionMultiselect());
                  if (store.state.prefState.isPreviewVisible) {
                    store.dispatch(TogglePreviewSidebar());
                  }
                }
              }),
            transactionIds,
            vendorId,
            categoryId,
          ),
        );
      },
    );
  }

  final AppState state;
  final List<TransactionEntity> transactions;
  final CompanyEntity company;
  final Function(BuildContext, EntityAction) onEntityAction;
  final Function(BuildContext) onRefreshed;
  final Function(BuildContext, List<String>) onConvertToPayment;
  final Function(BuildContext, String, String) onConvertToExpense;
  final bool isSaving;
  final bool isLoading;
}
