# Next Steps: Code Phase Implementation

## Overview
This document outlines the concrete next steps for the Code phase implementation of the sex toys catalog feature. Focus is on Phase 3 (Data Model & Magento Catalog Design) as the first coding phase after planning completion.

## Prerequisites Completed
- ✅ Planning documentation complete
- ✅ Business requirements defined
- ✅ Technical architecture approved
- ✅ Risk assessment completed
- ✅ Phase 1-2 (supplier/legal) in progress

## Phase 3: Data Model & Magento Catalog Design - Implementation Tasks

### 1. Magento Environment Setup and Verification
**Files to Create/Modify**:
- None (existing environment)

**Tasks**:
- [ ] Verify Magento 2 admin access and permissions
- [ ] Confirm existing product catalog structure
- [ ] Test current import/export functionality
- [ ] Document existing attribute sets and categories

**Environment Variables**:
```bash
# Verify existing Magento configuration
MAGENTO_BASE_URL=https://ogt-web.com
MAGENTO_ADMIN_USERNAME=admin
MAGENTO_ADMIN_PASSWORD=<encrypted>
MAGENTO_DB_HOST=<existing>
MAGENTO_DB_NAME=<existing>
```

### 2. Custom Product Attributes Creation
**Files to Create**:
- `magento-theme/Magento_Catalog/etc/module.xml` (if not exists)
- `magento-theme/Magento_Catalog/Setup/Patch/Data/AddSexToyAttributes.php`

**Magento Admin Tasks**:
- [ ] Create custom attribute group "Sex Toy Specifications"
- [ ] Add material attribute (dropdown: silicone, glass, stainless steel, etc.)
- [ ] Add usage type attribute (solo, partner, couples)
- [ ] Add care instructions attribute (text area)
- [ ] Add safety certifications attribute (multi-select)
- [ ] Add discreet packaging flag (yes/no)

**Attribute Configuration**:
```php
// Example attribute creation
'material' => [
    'type' => 'int',
    'label' => 'Material',
    'input' => 'select',
    'source' => 'Magento\Eav\Model\Entity\Attribute\Source\Table',
    'option' => [
        'values' => ['silicone', 'glass', 'stainless_steel', 'abs_plastic', 'other']
    ],
    'required' => true,
    'visible_on_front' => true,
    'used_in_product_listing' => true
]
```

### 3. Product Category Structure
**Magento Admin Tasks**:
- [ ] Create parent category "Intimacy & Wellness"
- [ ] Create subcategories: Solo, Couples, Accessories, Lubricants
- [ ] Configure category display settings (static block for educational content)
- [ ] Set up category-specific attributes and filters

**Category Configuration**:
```
Category Structure:
├── Intimacy & Wellness (ID: XXX)
    ├── For Solo Exploration (ID: XXX)
    ├── For Couples (ID: XXX)
    ├── Accessories (ID: XXX)
    └── Lubricants & Care (ID: XXX)
```

### 4. Attribute Sets Configuration
**Files to Create**:
- `magento-theme/Magento_Catalog/Setup/Patch/Data/CreateSexToyAttributeSet.php`

**Tasks**:
- [ ] Create "Sex Toy" attribute set based on default
- [ ] Add custom attribute groups: Specifications, Safety, Care
- [ ] Configure attribute visibility and requirements
- [ ] Test attribute set assignment to products

**Attribute Set Structure**:
```php
$attributeSet = [
    'attribute_set_name' => 'Sex Toy',
    'skeleton_id' => $defaultSetId, // Based on default
    'groups' => [
        'Specifications' => ['material', 'usage_type', 'dimensions'],
        'Safety' => ['certifications', 'body_safe', 'phthalate_free'],
        'Care' => ['care_instructions', 'maintenance']
    ]
];
```

### 5. Age Verification Logic Implementation
**Files to Create/Modify**:
- `magento-theme/Magento_Catalog/Model/Product/Attribute/Source/AgeVerification.php`
- `magento-theme/Magento_Catalog/Block/Product/View/AgeGate.php`
- `magento-theme/Magento_Catalog/view/frontend/templates/product/view/age-gate.phtml`
- `magento-theme/Magento_Catalog/view/frontend/web/js/age-verification.js`

**Tasks**:
- [ ] Create age verification product attribute (18+, 21+)
- [ ] Implement session-based age gate logic
- [ ] Add frontend modal for age confirmation
- [ ] Configure category-level age restrictions
- [ ] Test age verification flow

**JavaScript Implementation**:
```javascript
// Age verification modal logic
define(['jquery', 'Magento_Ui/js/modal/modal'], function($, modal) {
    return function(config) {
        var ageGateModal = modal({
            title: 'Age Verification Required',
            modalClass: 'age-verification-modal',
            buttons: [{
                text: $.mage.__('I am 18 or older'),
                class: 'action primary',
                click: function() {
                    // Set session cookie and close modal
                    $.cookie('age_verified', '1', { path: '/', expires: 1 });
                    this.closeModal();
                }
            }]
        });
        return ageGateModal;
    };
});
```

### 6. Product Templates Customization
**Files to Modify**:
- `magento-theme/Magento_Catalog/layout/catalog_product_view.xml`
- `magento-theme/Magento_Catalog/templates/product/view/details.phtml`
- `magento-theme/Magento_Catalog/templates/product/view/attributes.phtml`

**Tasks**:
- [ ] Customize product view layout for educational content
- [ ] Add care instructions section to product page
- [ ] Implement safety information display
- [ ] Configure materials and specifications display
- [ ] Test template rendering with sample products

**Layout Update**:
```xml
<referenceContainer name="product.info.main">
    <block class="Magento\Catalog\Block\Product\View\Description"
           name="product.care.instructions"
           template="Magento_Catalog::product/view/care-instructions.phtml"
           after="product.info.description"/>
</referenceContainer>
```

### 7. Import Template Development
**Files to Create**:
- `docs/sex_toy_import_template.csv` (documentation)
- `scripts/validate_sex_toy_import.php` (validation script)

**Tasks**:
- [ ] Define CSV import column mapping
- [ ] Create validation rules for custom attributes
- [ ] Develop import template with sample data
- [ ] Test import process with dummy products

**CSV Template Structure**:
```csv
sku,name,price,material,usage_type,care_instructions,is_body_safe,certifications,age_verification
ST001,"Silicone Vibrator",89.99,silicone,solo,"Clean with mild soap and water",1,"CE,FCC",18
ST002,"Glass Dildo",129.99,glass,couples,"Use lubricant, clean thoroughly",1,"CE,RoHS",18
```

### 8. Testing and Validation
**Tasks**:
- [ ] Create test products using new attribute set
- [ ] Verify category navigation and filtering
- [ ] Test age verification modal functionality
- [ ] Validate attribute display on product pages
- [ ] Confirm import template functionality
- [ ] Performance test with expanded catalog

**Test Cases**:
- [ ] Product creation with all custom attributes
- [ ] Category assignment and navigation
- [ ] Age verification session management
- [ ] Import validation and error handling
- [ ] Frontend display of educational content

## Environment Setup Requirements

### Development Environment
```bash
# Magento development setup
cd /path/to/magento
php bin/magento deploy:mode:set developer
php bin/magento cache:disable
php bin/magento setup:upgrade
php bin/magento setup:di:compile
```

### Database Backup
```bash
# Before making changes
mysqldump magento_db > backup_before_sex_toy_attributes.sql
```

### Version Control
```bash
# Create feature branch
git checkout -b feature/sex-toy-catalog
git add magento-theme/
git commit -m "Phase 3: Add sex toy product attributes and categories"
```

## Dependencies and Prerequisites

### Magento Extensions Required
- Magento_Catalog (core)
- Magento_Eav (core)
- Custom theme module (existing)

### External Dependencies
- None (all Magento core functionality)

### Team Prerequisites
- Magento developer with admin access
- Product manager for attribute validation
- Legal counsel for age verification requirements
- QA tester for functionality validation

## Success Criteria for Phase 3

### Functional Requirements
- [ ] All custom attributes created and configured
- [ ] Category structure implemented and navigable
- [ ] Age verification logic functional
- [ ] Product templates displaying educational content
- [ ] Import template validated and documented

### Technical Requirements
- [ ] No performance degradation (<2 second page loads)
- [ ] Database integrity maintained
- [ ] Backward compatibility preserved
- [ ] Error handling implemented for edge cases

### Quality Assurance
- [ ] Code reviewed and approved
- [ ] Unit tests written for custom logic
- [ ] Integration tests passing
- [ ] Cross-browser compatibility verified

## Risk Mitigation During Implementation

### Data Integrity Risks
- **Mitigation**: Database backup before changes, incremental testing
- **Rollback**: Attribute removal scripts prepared

### Performance Risks
- **Mitigation**: Load testing with expanded attributes
- **Monitoring**: Query performance analysis

### Compatibility Risks
- **Mitigation**: Test existing product catalog functionality
- **Validation**: Regression testing for current products

## Next Phase Handover

### Deliverables for Phase 4
- [ ] Complete attribute and category documentation
- [ ] Import template with validation rules
- [ ] Sample product data for testing
- [ ] Phase 3 implementation report

### Phase 4 Prerequisites
- [ ] Magento catalog structure ready
- [ ] Supplier product data available
- [ ] Import pipeline requirements defined

---

*Next Steps for Code Implementation - Phase 3 Focus - November 30, 2025*