
module.exports = (metas, params, options = {}) => Object.keys(metas).reduce((props, key) => {
    const propMeta = metas[key];
    //console.log('meta', key, propMeta);
    if (params[key]) {
        const value = params[key];
        if (!value.length) {
            throw new Error(`Property '${key}' is empty'`);
        }
        if (propMeta.type === 'integer') {
            props[key] = parseInt(value);
        } else {
            props[key] = value;
        }
    } else if (propMeta.default !== undefined) {
        props[key] = propMeta.default;
    } else if (options.required === false) {
    } else {
        const propMeta = metas[key];
        if (propMeta.required !== false) {
            throw new Error([
                `Missing required property:`,
                `'${key}' for the ${propMeta.description}`,
                `e.g. '${propMeta.example}'`
            ].join(' '));
        }
    }
    return props;
}, {});
