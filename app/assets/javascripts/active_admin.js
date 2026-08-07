//= require active_admin/base

//= require jquery
//= require chosen-jquery


document.addEventListener('DOMContentLoaded', function() {
  // Enable Chosen JS
  $('.chosen-select').chosen({
    allow_single_deselect: true,
    no_results_text: 'No results matched',
    width: '200px'
  });
});
