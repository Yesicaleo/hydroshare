from django.forms import ModelForm, Textarea, BaseFormSet
from django import forms
from crispy_forms.layout import *
from crispy_forms.helper import FormHelper
from crispy_forms.bootstrap import *
from hs_app_netCDF.models import *
from hs_core.forms import BaseFormHelper
from django.forms.models import formset_factory
from functools import partial, wraps


# The following 3 classes need to have the "field" same as the fields defined in "Variable" table in models.py
class OriginalCoverageSpatialForm(forms.Form):
    name = forms.CharField(max_length=200, required=False, label='Place/Area Name')
    projection = forms.CharField(max_length=100, required=False, label='Coordinate System/Geographic Projection')
    units = forms.CharField(max_length=50, label='Coordinate Units')
    northLimit = forms.DecimalField(label='North Longitude', widget=forms.TextInput())
    eastLimit = forms.DecimalField(label='East Latitude', widget=forms.TextInput())
    southLimit = forms.DecimalField(label='South Longitude', widget=forms.TextInput())
    westLimit = forms.DecimalField(label='West Latitude', widget=forms.TextInput())

class VariableFormHelper(BaseFormHelper):
    def __init__(self, allow_edit=True, res_short_id=None, element_id=None, element_name=None, *args, **kwargs):
        field_width = 'form-control input-sm'
        # change the fields name here
        layout = Layout(
                     Field('name', css_class=field_width),
                     Field('unit', css_class=field_width),
                     Field('type', css_class=field_width),
                     Field('shape', css_class=field_width),
                     Field('descriptive_name', css_class=field_width),
                     Field('method', css_class=field_width),
                     Field('missing_value', css_class=field_width)
                )

        super(VariableFormHelper, self).__init__(allow_edit, res_short_id,  element_id, element_name, layout,  *args, **kwargs)


class VariableForm(ModelForm):
    def __init__(self, allow_edit=True, res_short_id=None, element_id=None, *args, **kwargs):
        super(VariableForm, self).__init__(*args, **kwargs)
        self.helper = VariableFormHelper(allow_edit, res_short_id, element_id, element_name='Variable')
        self.delete_modal_form = None
        self.number = 0
        self.allow_edit = allow_edit
        if res_short_id:
            self.action = "/hsapi/_internal/%s/variable/add-metadata/" % res_short_id
        else:
            self.action = ""
        if not allow_edit:
            for field in self.fields.values():
                field.widget.attrs['readonly'] = True
                field.widget.attrs['style'] = "background-color:white;"
    @property
    def form_id(self):
        form_id = 'id_variable_%s' % self.number
        return form_id

    @property
    def form_id_button(self):
        form_id = 'id_variable_%s' % self.number
        return "'" + form_id + "'"

    class Meta:
        model = Variable
        # change the fields same here
        fields = ['name', 'unit', 'type', 'shape', 'descriptive_name', 'method', 'missing_value']
        exclude = ['content_object']
        # widgets = { 'name': forms.TextInput(attrs={'readonly': 'readonly'}),
        #             'unit': forms.TextInput(),
        #             'type': forms.TextInput(),
        #             'shape': forms.TextInput(attrs={'readonly': 'readonly'}),
        #             'descriptive_name': forms.TextInput(),
        #             'method': forms.Textarea(),#TODO row number abstract example
        #             'missing_value': forms.TextInput()}


class VariableValidationForm(forms.Form):
    name = forms.CharField(max_length=20)
    unit = forms.CharField(max_length=100)
    type = forms.CharField(max_length=100)
    shape = forms.CharField(max_length=100)
    descriptive_name = forms.CharField(max_length=100, required=False)
    method = forms.CharField(max_length=300, required=False)
    missing_value = forms.CharField(max_length=50, required=False)


ModalDialogLayoutAddVariable = Layout(
                            HTML('<div class="modal fade" id="add-variable-dialog" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">'
                                    '<div class="modal-dialog">'
                                        '<div class="modal-content">'
                                            '<form action="{{ add_variable_modal_form.action }}" method="POST" enctype="multipart/form-data"> '
                                            '{% csrf_token %} '
                                            '<input name="resource-mode" type="hidden" value="edit"/>'
                                            '<div class="modal-header">'
                                                '<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>'
                                                '<h4 class="modal-title" id="myModalLabel">Add Variable</h4>'
                                            '</div>'
                                            '<div class="modal-body">'
                                                '{% csrf_token %}'
                                                '<div class="form-group">'
                                                    '{% load crispy_forms_tags %} '
                                                    '{% crispy add_variable_modal_form %} '
                                                '</div>'
                                            '</div>'
                                            '<div class="modal-footer">'
                                                '<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>'
                                                '<button type="submit" class="btn btn-primary">Save changes</button>'
                                            '</div>'
                                            '</form>'
                                        '</div>'
                                    '</div>'
                                '</div>'
                            )
                        )


VariableLayoutEdit = Layout(
                            HTML('{% load crispy_forms_tags %} '
                                 '{% for form in variable_formset.forms %} '
                                     '<div class="item form-group"> '
                                     '<form id={{form.form_id}} action="{{ form.action }}" method="POST" enctype="multipart/form-data"> '
                                     '{% crispy form %} '
                                    '<div class="row" style="margin-top:10px">'
                                        '<div class="col-md-10">'
                                            '<input class="btn-danger btn btn-md" type="button" data-toggle="modal" data-target="#delete-variable-element-dialog_{{ form.number }}" value="Delete Variable">'
                                        '</div>' #change
                                        '<div class="col-md-2">'
                                            '<button type="button" class="btn btn-primary pull-right" onclick="metadata_update_ajax_submit({{ form.form_id_button }}); return false;">Save Changes</button>'  # change
                                        '</div>'
                                    '</div>'
                                    '{% crispy form.delete_modal_form %} '
                                    '</form> '
                                    '</div> '
                                '{% endfor %}'
                            ),
                            HTML('<div style="margin-top:10px">'
                                 '<p><a id="add-creator" class="btn btn-success" data-toggle="modal" data-target="#add-variable-dialog">'
                                 '<i class="fa fa-plus"></i>Add another variable</a>'
                                 '</div>'
                            ),
                    )