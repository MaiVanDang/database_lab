const express = require('express');
const router = express.Router();

const siteController = require('../app/controllers/SiteController');


router.post('/navbarsearch', siteController.navbarsearch);
router.get('/search', siteController.search);
router.post('/searchproductid', siteController.searchproductid);
router.post('/searchcatalogprice', siteController.searchcatalogprice);

router.use('/customer', siteController.customer);
router.use('/searchcustomer', siteController.searchcustomer);
router.use('/addcustomer', siteController.addcustomer);
router.use('/editcustomer/:id', siteController.editcustomer);
router.use('/updatecustomer/:id', siteController.updatecustomer);
router.use('/deletecustomer/:id', siteController.deletecustomer); // hiển thị trang deletecustomer
router.use('/removecustomer/:id', siteController.removecustomer); // xoá customer

router.use('/product', siteController.product);
router.use('/searchproduct', siteController.searchproduct);
router.use('/addproduct', siteController.addproduct);
router.use('/editproduct/:id', siteController.editproduct);
router.use('/updateproduct/:id', siteController.updateproduct);
router.use('/deleteproduct/:id', siteController.deleteproduct); // hiển thị trang deleteproduct
router.use('/removeproduct/:id', siteController.removeproduct); // xoá product

router.use('/supplier', siteController.supplier);
router.use('/searchsupplier', siteController.searchsupplier);
router.use('/addsupplier', siteController.addsupplier);
router.use('/editsupplier/:id', siteController.editsupplier);
router.use('/updatesupplier/:id', siteController.updatesupplier);
router.use('/deletesupplier/:id', siteController.deletesupplier); // hiển thị trang deletesupplier
router.use('/removesupplier/:id', siteController.removesupplier); // xoá supplier

router.use('/order', siteController.order);
router.use('/searchorder', siteController.searchorder.bind(siteController));
router.use('/addorder', siteController.addorder);
router.use('/manageorder',siteController.manageorder);
router.use('/searchorderid',siteController.searchorderid);
router.use('/editorder/:id', siteController.editorder);
router.use('/updateorder/:id', siteController.updateorder);
router.post('/updatestatusorder/:id', siteController.updatestatusorder.bind(siteController));
router.post('/refundorder/:id', siteController.refundorder.bind(siteController));
router.post('/paidorder/:id', siteController.paidorder.bind(siteController));

router.use('/statistic', siteController.statistic);
router.post('/basepricesupplier', siteController.basepricesupplier);
router.post('/revenuesupplier', siteController.revenuesupplier);
router.post('/revenueproduct', siteController.revenueproduct);

router.get('/getcatalog', siteController.getcatalog);
router.get('/getsupplier', siteController.getsupplier);


router.get('/test', siteController.test);
router.use('/', siteController.index);

module.exports = router;
