import React from 'react';
import ReactDOM from 'react-dom';

import AlertDisplay from "./activity_components/alert_display"
import ActivityDescription from "./activity_components/activity_description"
import PrintersSelection from "./activity_components/printers_selection"
import AssetGroupsEditor from "./asset_group_components/asset_groups_editor"
import StepsFinished from "./step_components/steps_finished"
import StepTypesControl from "./step_type_components/step_types_control"


import {FormFor, HashFields} from "react-rails-form-helpers"

class Activity extends React.Component {
	constructor(props) {
		super()
		this.state = {
			selectedTubePrinter: props.tubePrinter.defaultValue,
			selectedPlatePrinter: props.platePrinter.defaultValue,
			selectedAssetGroup: props.activity.selectedAssetGroup,
			stepTypes: props.stepTypes,
			assetGroups: props.assetGroups,
			messages: []
		}
		this.onSelectAssetGroup = this.onSelectAssetGroup.bind(this)
		this.onChangeAssetGroup = this.onChangeAssetGroup.bind(this)
		this.onErrorMessage = this.onErrorMessage.bind(this)
		this.onRemoveErrorMessage = this.onRemoveErrorMessage.bind(this)
		this.onRemoveAssetFromAssetGroup = this.onRemoveAssetFromAssetGroup.bind(this)
		this.onRemoveAllAssetsFromAssetGroup = this.onRemoveAllAssetsFromAssetGroup.bind(this)
	}
	onRemoveErrorMessage(msg, pos) {
		this.state.messages.splice(pos,1)
		this.setState({messages: this.state.messages})
	}
	onErrorMessage(msg) {
		this.state.messages.push(msg)
		this.setState({messages: this.state.messages})
	}
	onSelectAssetGroup(assetGroup) {
		this.setState({selectedAssetGroup: assetGroup.id})
	}
	onChangeAssetGroup(msg) {
		this.state.assetGroups[msg.asset_group.id]=msg.asset_group
		this.state.stepTypes[msg.asset_group.id]=msg.step_types

		this.setState({
			assetGroups: this.state.assetGroups,
			stepTypes: this.state.stepTypes
		})
	}
	changeAssetGroup(assetGroup, data) {
		$.ajax({
      method: 'PUT',
			dataType: 'json',
			contentType: 'application/json; charset=utf-8',
      url: assetGroup.updateUrl,
      success: this.onChangeAssetGroup,
      data: JSON.stringify(data)
    })
	}
	onRemoveAssetFromAssetGroup(assetGroup, asset, pos){
		let assets = this.state.assetGroups[assetGroup.id].assets.slice()
		assets.splice(pos, 1)
		const uuids = assets.map((a) => { return a.uuid })

		this.changeAssetGroup(assetGroup, {
			asset_group: {
				assets: uuids
			}
		})
	}
	onRemoveAllAssetsFromAssetGroup(assetGroup){
		this.changeAssetGroup(assetGroup, {
			asset_group: {
				assets: []
			}
		})
	}

	onChangeTubePrinter() {
		this.setState({selectedTubePrinter: e.target.value})
	}
	onChangePlatePrinter() {
		this.setState({selectedPlatePrinter: e.target.value})
	}
	renderStepTypesControl() {
		return(
			<StepTypesControl stepTypes={this.state.stepTypes}
				selectedAssetGroup={this.state.selectedAssetGroup}
				selectedTubePrinter={this.state.selectedTubePrinter}
				selectedPlatePrinter={this.state.selectedPlatePrinter}
				/>
		)
	}
  render () {
    return (
      <div>
				<AlertDisplay
					onRemoveErrorMessage={this.onRemoveErrorMessage}
					messages={this.state.messages} />
	      <FormFor url='/edu' className="form-inline activity-desc">
	        <HashFields name="activity">
	          <ActivityDescription	activity={this.props.activity} />
	        </HashFields>
	      </FormFor>
	      <PrintersSelection
	      	selectedTubePrinter={this.state.selectedTubePrinter}
	      	selectedPlatePrinter={this.state.selectedPlatePrinter}
		     	tubePrinter={this.props.tubePrinter}
		     	platePrinter={this.props.platePrinter}
		     	onChangeTubePrinter={this.onChangeTubePrinter}
		     	onChangePlatePrinter={this.onChangePlatePrinter}
		    />
				{this.renderStepTypesControl()}
			  <AssetGroupsEditor
					onRemoveAssetFromAssetGroup={this.onRemoveAssetFromAssetGroup}
					onRemoveAllAssetsFromAssetGroup={this.onRemoveAllAssetsFromAssetGroup}
					onErrorMessage={this.onErrorMessage}
					onChangeAssetGroup={this.onChangeAssetGroup}
					selectedAssetGroup={this.state.selectedAssetGroup}
					onSelectAssetGroup={this.onSelectAssetGroup}
					assetGroups={this.props.assetGroups} />
				{this.renderStepTypesControl()}

				<StepsFinished steps={this.props.stepsFinished} />
      </div>
    )
  }
}

export default Activity
