document.addEventListener('sopasjs-ready', () => {
  const page_1 = document.querySelector('div.sopasjs-ui-navbar-wrapper > div > ul > li:nth-child(3) > a > i');
  page_1.classList.remove('fa-file');
  page_1.classList.add('fa-exchange');

  const page_FirstLabel = document.querySelector('div.sopasjs-ui-navbar-wrapper > div > ul > li:nth-child(2)');
  const page_App = document.querySelector('div.sopasjs-ui-navbar-wrapper > div > ul > li:nth-child(4)');
  const page_Setup = document.querySelector('div.sopasjs-ui-navbar-wrapper > div > ul > li:nth-child(5) > a');

  page_FirstLabel.remove();
  page_App.remove();
  page_Setup.remove();

  setTimeout(() => {
    document.title = 'CSK_Module_MultiIOLinkSMI'
  }, 500);
})