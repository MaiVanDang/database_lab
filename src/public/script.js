const pathName = window.location.pathname;
const pageName = pathName.split('/').pop();

if (pageName === '') {
    document.querySelector('.home').classList.add('active');
}
if (pageName === 'search') {
    document.querySelector('.search').classList.add('active');
}

if (pageName === 'contact') {
    document.querySelector('.contact').classList.add('active');
}
