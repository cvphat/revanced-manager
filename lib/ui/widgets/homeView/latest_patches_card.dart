import 'package:flutter/cupertino.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:revanced_manager/ui/views/home/home_viewmodel.dart';
import 'package:revanced_manager/ui/widgets/shared/custom_card.dart';
import 'package:revanced_manager/ui/widgets/shared/custom_material_button.dart';
import 'package:stacked/stacked.dart';

class LatestPatchesCard extends ViewModelWidget<HomeViewModel> {
  const LatestPatchesCard({super.key});

  @override
  Widget build(BuildContext context, HomeViewModel viewModel) {
    return CustomCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  I18nText('latestPatchesCard.statusLabel'),
                  Text(
                    viewModel.noPatchesLoaded
                        ? FlutterI18n.translate(
                            context,
                            'latestPatchesCard.failedStatusLabel',
                          )
                        : FlutterI18n.translate(
                            context,
                            'latestPatchesCard.loadedStatusLabel',
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Visibility(
                visible: viewModel.patchesVersion != null,
                child: Row(
                  children: [
                    I18nText('latestPatchesCard.versionLabel'),
                    Text(viewModel.patchesVersion!),
                  ],
                ),
              ),
            ],
          ),
          Visibility(
            visible: viewModel.noPatchesLoaded,
            child: CustomMaterialButton(
              isExpanded: false,
              label: I18nText('latestPatchesCard.loadButton'),
              onPressed: () {
                viewModel.loadLocalPatches();
              },
            ),
          )
        ],
      ),
    );
  }
}
